class_name VitrineCarro
extends SubViewportContainer
## Carro de blocos girando num piso, como a vitrine da oficina do GT2.
## Placeholder: troca por modelo definitivo sem mudar quem usa.

const VELOCIDADE := 0.5  # rad/s

var _carro: CarroBloco
var _mundo: Node3D


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 300)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	_mundo = Node3D.new()
	vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	amb.environment = env
	_mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.9, 0.6, 0)
	_mundo.add_child(luz)
	var piso := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 3.6
	disco.bottom_radius = 3.6
	disco.height = 0.05
	piso.mesh = disco
	piso.material_override = CarroBloco._material(Color(0.24, 0.25, 0.29))
	piso.position.y = -0.03
	_mundo.add_child(piso)
	var cam := Camera3D.new()
	cam.fov = 40
	_mundo.add_child(cam)
	cam.position = Vector3(5.0, 2.6, 5.0)
	cam.look_at_from_position(cam.position, Vector3(0, 0.6, 0))
	_carro = CarroBloco.new()
	_mundo.add_child(_carro)


func mostrar(categoria: String, cor: Color) -> void:
	_carro.configurar(categoria, cor)


func _process(delta: float) -> void:
	if is_visible_in_tree() and not Preferencias.reduzir_animacoes:
		_carro.rotation.y += VELOCIDADE * delta
