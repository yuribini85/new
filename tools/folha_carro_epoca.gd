extends SceneTree
## Folha do carro de época (CarroEpoca) em quatro vistas: lado, três-quartos
## de frente, três-quartos de trás e frente. Para comparar com a silhueta de
## referência e iterar o desenho.
## Uso (precisa de tela: xvfb-run): godot --script res://tools/folha_carro_epoca.gd -- --saida=/caminho.png [--modelo=cupe_1928] [--cor=7a2a26]

const VISTA := Vector2i(800, 480)


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://folha_carro_epoca.png"
	var modelo := "cupe_1928"
	var cor := Color("7a2a26")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--modelo="):
			modelo = arg.trim_prefix("--modelo=")
		elif arg.begins_with("--cor="):
			cor = Color(arg.trim_prefix("--cor="))
	var fundo := ColorRect.new()
	fundo.color = Color(0.1, 0.09, 0.08)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fundo)
	var vps := []
	# [posição da câmera, alvo, ortogonal (tamanho) ou 0 para perspectiva]
	var vistas := [
		[Vector3(9, 0.85, 0), Vector3(0, 0.85, 0), 4.6],
		[Vector3(4.6, 1.9, 5.4), Vector3(0, 0.75, 0.1), 0.0],
		[Vector3(-4.4, 2.2, -5.4), Vector3(0, 0.75, -0.1), 0.0],
		[Vector3(0, 0.95, 9), Vector3(0, 0.85, 0), 2.9],
	]
	for v in vistas:
		var vp := SubViewport.new()
		vp.size = VISTA
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		vps.append(vp)
		_cena(vp, modelo, cor, v)
	for k in 20:
		await process_frame
	# as quatro vistas numa folha 2 × 2
	var folha := Image.create(VISTA.x * 2, VISTA.y * 2, false, Image.FORMAT_RGBA8)
	for k in vps.size():
		var img: Image = vps[k].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, VISTA), Vector2i(k % 2, k / 2) * VISTA)
	folha.save_png(saida)
	quit()


func _cena(vp: SubViewport, modelo: String, cor: Color, v: Array) -> void:
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.19, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	CarroBloco.reflexo(env)
	amb.environment = env
	mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.8, 0.7, 0)
	luz.light_energy = 1.3
	luz.shadow_enabled = true
	mundo.add_child(luz)
	var recorte := DirectionalLight3D.new()
	recorte.rotation = Vector3(-0.35, PI + 0.5, 0)
	recorte.light_energy = 0.6
	recorte.light_color = Color(0.75, 0.85, 1.0)
	mundo.add_child(recorte)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(30, 30)
	chao.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.29, 0.27)
	mat.roughness = 0.9
	chao.material_override = mat
	mundo.add_child(chao)
	var carro := CarroEpoca.construir(modelo, cor)
	mundo.add_child(carro)
	var cam := Camera3D.new()
	mundo.add_child(cam)
	if float(v[2]) > 0.0:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(v[2])
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
	else:
		cam.fov = 30.0
	cam.look_at_from_position(v[0], v[1])
