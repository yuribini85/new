class_name VitrineCarro
extends SubViewportContainer
## Carro girando num estúdio (piso, luz de recorte, fundo escuro), como a
## vitrine da garagem do GT2. Arrastar com o dedo gira o carro.

const VELOCIDADE := 0.35  # rad/s

var _carro: CarroBloco
var _mundo: Node3D
var _arrastando := false
var _ultimo_toque := 0.0
## Garagem: carro parado num ambiente de oficina, só balançando devagar.
var _garagem := false
var _angulo := -0.5
var _luz: DirectionalLight3D
var _piso: MeshInstance3D
var _anel: MeshInstance3D


func _init(altura := 300.0) -> void:
	stretch = true
	custom_minimum_size = Vector2(0, altura)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	_mundo = Node3D.new()
	vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.075, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.58)
	amb.environment = env
	_mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.85, 0.7, 0)
	luz.light_energy = 0.85
	_mundo.add_child(luz)
	_luz = luz
	var recorte := DirectionalLight3D.new()
	recorte.rotation = Vector3(-0.3, PI + 0.6, 0)
	recorte.light_energy = 0.45
	var frente := DirectionalLight3D.new()
	frente.rotation = Vector3(-0.2, 0.9, 0)
	frente.light_energy = 0.3
	_mundo.add_child(frente)
	recorte.light_color = Color(0.7, 0.8, 1.0)
	_mundo.add_child(recorte)
	var piso := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 3.8
	disco.bottom_radius = 3.9
	disco.height = 0.06
	disco.radial_segments = 48
	piso.mesh = disco
	piso.material_override = CarroBloco._material(Color(0.13, 0.135, 0.16))
	piso.position.y = -0.04
	_mundo.add_child(piso)
	_piso = piso
	var anel := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 3.75
	t.outer_radius = 3.9
	anel.mesh = t
	# Borda discreta: o carro é o destaque, não a plataforma.
	anel.material_override = CarroBloco._material(Color(0.24, 0.25, 0.29))
	_mundo.add_child(anel)
	_anel = anel
	var cam := Camera3D.new()
	cam.fov = 30
	_mundo.add_child(cam)
	cam.look_at_from_position(Vector3(6.2, 2.4, 6.8), Vector3(0, 0.5, 0))
	_carro = CarroBloco.new()
	_carro.rotation.y = -0.5
	_mundo.add_child(_carro)


func mostrar(categoria: String, cor: Color) -> void:
	_carro.configurar(categoria, cor)


func mostrar_modelo(base: Dictionary, cor: Color) -> void:
	_carro.configurar_modelo(base, cor)


## Troca o estúdio por uma oficina: piso de ladrilhos, paredes, armário,
## pneus empilhados, bancada, luminária e sombra de verdade.
func ambiente_garagem() -> void:
	if _garagem:
		return
	_garagem = true
	_piso.visible = false
	_anel.visible = false
	_luz.shadow_enabled = true
	_luz.rotation = Vector3(-1.1, 0.5, 0)
	var claro := CarroBloco._material(Color(0.42, 0.43, 0.46))
	var escuro := CarroBloco._material(Color(0.3, 0.31, 0.34))
	for i in range(-6, 7):
		for k in range(-6, 7):
			var ladrilho := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(1.0, 0.04, 1.0)
			ladrilho.mesh = b
			ladrilho.material_override = claro if (i + k) % 2 == 0 else escuro
			ladrilho.position = Vector3(i, -0.02, k)
			_mundo.add_child(ladrilho)
	var parede := CarroBloco._material(Color(0.62, 0.63, 0.66))
	var faixa := CarroBloco._material(Color(0.85, 0.65, 0.12))
	for p in [[Vector3(13.0, 4.0, 0.2), Vector3(0, 2.0, -6.5)], [Vector3(0.2, 4.0, 13.0), Vector3(-6.5, 2.0, 0)]]:
		_bloco(p[0], p[1], parede)
		_bloco(Vector3(p[0].x, 0.25, p[0].z) + Vector3(0.02, 0, 0.02), p[1] + Vector3(0, -0.9, 0), faixa)
	# Armário de ferramentas vermelho com gavetas.
	var vermelho := CarroBloco._material(Color(0.75, 0.12, 0.1))
	_bloco(Vector3(1.6, 1.4, 0.7), Vector3(-3.2, 0.7, -6.0), vermelho)
	for g in 4:
		_bloco(Vector3(1.45, 0.04, 0.02), Vector3(-3.2, 0.3 + g * 0.3, -5.64), CarroBloco._material(Color(0.2, 0.2, 0.22)))
	# Bancada.
	var madeira := CarroBloco._material(Color(0.45, 0.32, 0.2))
	_bloco(Vector3(2.4, 0.1, 0.8), Vector3(1.6, 1.0, -6.0), madeira)
	for x in [0.5, 2.7]:
		_bloco(Vector3(0.1, 1.0, 0.7), Vector3(x, 0.5, -6.0), escuro)
	# Pneus empilhados no canto.
	var borracha := CarroBloco._material(Color(0.08, 0.08, 0.09))
	for n in 4:
		var pneu := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.36
		cil.bottom_radius = 0.36
		cil.height = 0.24
		cil.radial_segments = 16
		pneu.mesh = cil
		pneu.material_override = borracha
		pneu.position = Vector3(-5.6, 0.12 + n * 0.25, -5.4)
		_mundo.add_child(pneu)
	# Luminária com luz quente sobre o carro.
	var lampada := CarroBloco._material(Color(1.0, 0.95, 0.8))
	lampada.emission_enabled = true
	lampada.emission = Color(1.0, 0.92, 0.75)
	_bloco(Vector3(2.4, 0.08, 0.3), Vector3(0, 3.6, 0), lampada)
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 3.3, 0)
	luz.omni_range = 9.0
	luz.light_energy = 0.8
	luz.light_color = Color(1.0, 0.93, 0.8)
	_mundo.add_child(luz)


func _bloco(tam: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	_mundo.add_child(mi)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_angulo += ev.relative.x * 0.01
		_carro.rotation.y = _angulo
		_ultimo_toque = Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	# Gira sozinho, exceto logo depois de o jogador girar com o dedo.
	if not is_visible_in_tree() or Preferencias.reduzir_animacoes \
			or Time.get_ticks_msec() / 1000.0 - _ultimo_toque < 3.0:
		return
	if _garagem:
		# Na garagem o carro fica parado para ser observado: só balança devagar.
		_carro.rotation.y = _angulo + sin(Time.get_ticks_msec() / 1000.0 * 0.35) * 0.3
	else:
		_angulo += VELOCIDADE * delta
		_carro.rotation.y = _angulo
