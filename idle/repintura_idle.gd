class_name RepinturaIdle
extends Control
## Depois da primeira vitória o Tony pinta o carro do ferro-velho (The
## Fastfather): no galpão, o carro gira enquanto a ferrugem, a poeira e os
## riscos somem e a lataria escurece até o preto da família; no fim entra a
## pintura nova (o 13), com faíscas e o letreiro. Toque fecha depois disso;
## sozinha, fecha em alguns segundos.

signal fechou

## Apresentação, não balanceamento.
const PINTAR_S := 1.8
const FICA_S := 2.4

var _carro: CarroBloco
var _giro: Node3D
var _letreiro: Label
var _pronto := false
var _t := 0.0


func _init(estado: IdleEstado, c: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := TextureRect.new()
	fundo.texture = load("res://arte/fastfather/loja/fundo.webp")
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # escala uniforme, recorta
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.offset_top = 260
	cont.offset_bottom = -260
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_4X
	cont.add_child(vp)
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	CarroBloco.reflexo(env)
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.42, 0.36)
	amb.environment = env
	mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.6, 0.8, 0)
	luz.light_energy = 0.6
	luz.light_color = GaragemIdle.LUZ
	mundo.add_child(luz)
	var foco := SpotLight3D.new()
	foco.position = Vector3(0, 4.6, 0.6)
	foco.rotation = Vector3(-PI / 2.0 + 0.12, 0, 0)
	foco.spot_angle = 42.0
	foco.spot_range = 10.0
	foco.light_energy = 2.6
	foco.light_color = GaragemIdle.LUZ
	mundo.add_child(foco)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 30.0
	mundo.add_child(cam)
	cam.look_at_from_position(GaragemIdle.CAMERA, GaragemIdle.ALVO)
	_giro = Node3D.new()
	_giro.rotation.y = -0.6
	mundo.add_child(_giro)
	_carro = CarroBloco.new()
	_giro.add_child(_carro)
	_giro.add_child(GaragemIdle.sombra_chao())
	var velho := PinturaEpoca.ferro_velho(true)
	_carro.configurar_modelo({"id": String(c["id"]), "epoca": String(c["modelo"])}, velho[0], velho[1])
	var titulo := IdleUI.rotulo("A OFICINA DO TONY", 34, IdleUI.COR_OURO_CLARO, self, "deco")
	titulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = AreaSegura.topo(720.0) + 60
	titulo.offset_bottom = titulo.offset_top + 80
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GaragemIdle._contorno(titulo)
	_letreiro = IdleUI.rotulo("PINTURA NOVA DA FAMÍLIA", 40, IdleUI.COR_OURO_CLARO, self, "deco")
	_letreiro.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_letreiro.offset_top = -AreaSegura.base(720.0) - 220
	_letreiro.offset_bottom = _letreiro.offset_top + 90
	_letreiro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letreiro.modulate.a = 0.0
	GaragemIdle._contorno(_letreiro)
	_pintar.call_deferred(estado, c)


## A lataria do ferro-velho perde a ferrugem e escurece (os parâmetros do
## shader), e no fim troca para a pintura da família.
func _pintar(estado: IdleEstado, c: Dictionary) -> void:
	var r := 0.0 if Preferencias.reduzir_animacoes else 1.0
	var sm: ShaderMaterial = null
	var corpo := _carro.find_child("Carroceria", true, false) as MeshInstance3D
	if corpo != null:
		for k in corpo.get_surface_override_material_count():
			if corpo.get_surface_override_material(k) is ShaderMaterial:
				sm = corpo.get_surface_override_material(k)
	var final := GaragemIdle.pintura(estado, c)
	if sm != null and r > 0.0:
		await get_tree().create_timer(0.5).timeout
		Sons.tocar_ui(self, "passagem", -8.0, 0.7)
		var de: Color = sm.get_shader_parameter("cor_base")
		var tw := create_tween().set_parallel()
		for p in ["ferrugem", "poeira", "arranhoes"]:
			tw.tween_method(func(v: float): sm.set_shader_parameter(p, v), float(sm.get_shader_parameter(p)), 0.0, PINTAR_S)
		tw.tween_method(func(v: Color): sm.set_shader_parameter("cor_base", v), de, final[0], PINTAR_S)
		await tw.finished
	_carro.configurar_modelo({"id": String(c["id"]), "epoca": String(c["modelo"])}, final[0], final[1])
	Sons.tocar_ui(self, "moeda", -4.0)
	_pronto = true
	var t2 := create_tween()
	t2.tween_property(_letreiro, "modulate:a", 1.0, 0.25 * r + 0.01)
	t2.tween_interval(FICA_S)
	t2.tween_callback(_fechar)


func _fechar() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		fechou.emit()
		queue_free())


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if toque:
		accept_event()
		if _pronto:
			_fechar()


func _process(delta: float) -> void:
	_t += delta
	if not Preferencias.reduzir_animacoes:
		_giro.rotation.y += GaragemIdle.GIRO * delta
