class_name VitrineCarro
extends SubViewportContainer
## Carro girando num estúdio (piso, luz de recorte, fundo escuro), como a
## vitrine da garagem do GT2. Arrastar com o dedo gira o carro.

const VELOCIDADE := 0.35  # rad/s

var _carro: CarroBloco
var _mundo: Node3D
var _arrastando := false
var _ultimo_toque := 0.0


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
	var anel := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 3.75
	t.outer_radius = 3.9
	anel.mesh = t
	# Borda discreta: o carro é o destaque, não a plataforma.
	anel.material_override = CarroBloco._material(Color(0.24, 0.25, 0.29))
	_mundo.add_child(anel)
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


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_carro.rotation.y += ev.relative.x * 0.01
		_ultimo_toque = Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	# Gira sozinho, exceto logo depois de o jogador girar com o dedo.
	if is_visible_in_tree() and not Preferencias.reduzir_animacoes \
			and Time.get_ticks_msec() / 1000.0 - _ultimo_toque > 3.0:
		_carro.rotation.y += VELOCIDADE * delta
