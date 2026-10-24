class_name Incendio3D
extends Node3D
## Fumaça, fogo e explosão de um carro na arena (pacote de dano aprovado pelo
## usuário; adaptado de vehicle_damage.gd). Só tela: quem decide quando cada
## fase começa é a simulação (eventos fogo, fuga e explosao de Arena.correr).
## Fases: fumaça clara (dano alto) → escurece com o carro eliminado (motor
## parado) → fogo → porta abre e o piloto sai → explosão (rodas e chapas
## soltam, carcaça chamuscada) → o fogo diminui e apaga → a fumaça se dissipa.
## Cor no material, não na partícula: no renderizador de compatibilidade a cor
## da partícula chegava preta (a "bola preta" no capô).

## Tempos depois da explosão (pacote): o fogo enfraquece de 4 a 9 s, apaga aos
## 9 s; a fumaça some de 9 a 12 s.
const FOGO_CAI_S := Vector2(4.0, 9.0)
const FUMACA_SOME_S := Vector2(9.0, 12.0)
## O motor parado escurece a fumaça em 4 s (pacote: 3 → 7 s).
const ESCURECE_S := 4.0
const CLARA := Color(.72, .73, .70)
const ESCURA := Color(.10, .10, .09)
const ALFA_CLARA := 0.10
const ALFA_ESCURA := 0.28

## Onde fica o motor, no carro (frente em +X).
var motor := Vector3(1.3, 0.9, 0.0)
var _fumaca: CPUParticles3D
var _mat_fumaca: StandardMaterial3D
var _chamas: CPUParticles3D
var _mat_chamas: StandardMaterial3D
var _brilho: OmniLight3D
var _escuro := 0.0
var _parado := false
var _fogo := false
var _explodiu := -1.0  # tempo desde a explosão; < 0 antes
var _t := 0.0

static var _textura: Texture2D


## Fumaça leve (dano alto); `parado` (eliminado) a escurece aos poucos.
func fumacar(parado: bool) -> void:
	if _fumaca == null:
		_fumaca = _emissor(motor + Vector3(0, .1, 0), 48, 3.0, false)
		_mat_fumaca = _fumaca.mesh.surface_get_material(0)
		_fumaca.direction = Vector3.UP
		_fumaca.spread = 10
		_fumaca.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_fumaca.emission_box_extents = Vector3(.12, .02, .12)
		_fumaca.gravity = Vector3(.11, .12, .03)
		_fumaca.initial_velocity_min = .45
		_fumaca.initial_velocity_max = .70
		_fumaca.scale_amount_min = 1.2
		_fumaca.scale_amount_max = 2.2
		var cresce := Curve.new()
		cresce.add_point(Vector2(0, .18))
		cresce.add_point(Vector2(.3, .85))
		cresce.add_point(Vector2(1, 1.9))
		_fumaca.scale_amount_curve = cresce
		_cor_fumaca(CLARA, ALFA_CLARA)
	_parado = _parado or parado


func fogo() -> void:
	fumacar(true)
	if _fogo:
		return
	_fogo = true
	_chamas = _emissor(motor, 40, .85, true)
	_mat_chamas = _chamas.mesh.surface_get_material(0)
	_chamas.direction = Vector3.UP
	_chamas.spread = 22
	_chamas.gravity = Vector3(0, 1.1, 0)
	_chamas.initial_velocity_min = .7
	_chamas.initial_velocity_max = 1.8
	_chamas.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_chamas.emission_box_extents = Vector3(.48, .08, .42)
	_chamas.scale_amount_min = .5
	_chamas.scale_amount_max = .95
	var some := Curve.new()
	some.add_point(Vector2(0, .4))
	some.add_point(Vector2(.3, 1.0))
	some.add_point(Vector2(1, 0))
	_chamas.scale_amount_curve = some
	_brilho = OmniLight3D.new()
	_brilho.light_color = Color(1, .35, .06)
	_brilho.omni_range = 5
	_brilho.light_energy = 1.2
	add_child(_brilho)
	_brilho.position = motor + Vector3(0, .2, 0)


## A explosão: clarão, chamas para todo lado e o fogo que depois diminui.
func explodir() -> void:
	fogo()
	_explodiu = 0.0
	var clarao := _emissor(motor + Vector3(-.3, .1, 0), 80, .85, true)
	clarao.one_shot = true
	clarao.explosiveness = 1
	clarao.direction = Vector3.UP
	clarao.spread = 180
	clarao.initial_velocity_min = 2
	clarao.initial_velocity_max = 6
	clarao.gravity = Vector3(0, -1, 0)
	clarao.scale_amount_min = 1.3
	clarao.scale_amount_max = 1.3
	(clarao.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(1, .75, .3, .95)
	clarao.emitting = true
	_brilho.light_energy = 8
	create_tween().tween_property(_brilho, "light_energy", 1.0, .45)


func _process(delta: float) -> void:
	_t += delta
	if _fumaca != null and _parado and _explodiu < 0.0:
		_escuro = minf(_escuro + delta / ESCURECE_S, 1.0)
		_cor_fumaca(CLARA.lerp(ESCURA, _escuro), lerpf(ALFA_CLARA, ALFA_ESCURA, _escuro))
	if _brilho != null and _explodiu < FOGO_CAI_S.x:
		_brilho.light_energy = maxf(_brilho.light_energy, 1.2 + sin(_t * 27) * .2) if _explodiu < 0.0 \
				else _brilho.light_energy
	if _explodiu < 0.0:
		return
	_explodiu += delta
	var forca := 1.0 - smoothstep(FOGO_CAI_S.x, FOGO_CAI_S.y, _explodiu)
	if _mat_chamas != null:
		_mat_chamas.albedo_color.a = .9 * forca
	if _explodiu >= FOGO_CAI_S.x and _brilho != null:
		_brilho.light_energy = forca
	if _explodiu >= FOGO_CAI_S.y and _chamas != null and _chamas.emitting:
		_chamas.emitting = false
		_brilho.light_energy = 0
	if _explodiu >= FOGO_CAI_S.y and _fumaca != null:
		_cor_fumaca(ESCURA, ALFA_ESCURA * (1.0 - smoothstep(FUMACA_SOME_S.x, FUMACA_SOME_S.y, _explodiu)))
		if _explodiu >= FUMACA_SOME_S.y:
			_fumaca.emitting = false


func _cor_fumaca(c: Color, a: float) -> void:
	_mat_fumaca.albedo_color = Color(c, a)


func _emissor(onde: Vector3, quantos: int, vida: float, quente: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = quantos
	p.lifetime = vida
	p.local_coords = false
	p.position = onde
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _textura_fumaca()
	m.render_priority = 36 if quente else 35
	if quente:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1, .55, .12, .9)
	q.material = m
	p.mesh = q
	add_child(p)
	p.emitting = true
	return p


## Mancha macia com ruído (do pacote): sem borda dura, sem mancha preta.
static func _textura_fumaca() -> Texture2D:
	if _textura != null:
		return _textura
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 93
	ruido.frequency = .11
	for y in 64:
		for x in 64:
			var r := Vector2((x - 31.5) / 31.5, (y - 31.5) / 31.5).length()
			var a := pow(maxf(0, 1 - r * r), 2) * (.75 + .25 * ruido.get_noise_2d(x, y))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_textura = ImageTexture.create_from_image(img)
	return _textura
