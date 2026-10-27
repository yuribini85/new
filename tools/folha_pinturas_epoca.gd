extends SceneTree
## Folha das pinturas de época (PinturaEpoca): uma linha por família, o carro
## do jogador e rivais, em três-quartos de frente.
## Uso (precisa de tela: xvfb-run): godot --script res://tools/folha_pinturas_epoca.gd -- --saida=/caminho.png

const CELULA := Vector2i(400, 250)
const LINHAS := [["bairro", "cupe_1928"], ["hot_rod", "hotrod_1932"], ["hot_rod", "cupe_1940"], ["stock", "seda_1951"],
		["familias", "cupe_1940"]]
const POR_LINHA := 5


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var saida := "user://folha_pinturas_epoca.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			saida = arg.trim_prefix("--saida=")
	var vps := []
	for l in LINHAS:
		for k in POR_LINHA:
			var pe: Array = PinturaEpoca.do_jogador(l[0]) if k == 0 else PinturaEpoca.do_rival(l[0], "equipe%d" % k, "s%d" % k, 4 * k + 2)
			var vp := SubViewport.new()
			vp.size = CELULA
			vp.own_world_3d = true
			vp.msaa_3d = Viewport.MSAA_4X
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			_cena(vp, l[1], pe)
			vps.append(vp)
	for k in 20:
		await process_frame
	var folha := Image.create(CELULA.x * POR_LINHA, CELULA.y * LINHAS.size(), false, Image.FORMAT_RGBA8)
	for k in vps.size():
		var img: Image = vps[k].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		folha.blit_rect(img, Rect2i(Vector2i.ZERO, CELULA), Vector2i(k % POR_LINHA, k / POR_LINHA) * CELULA)
	folha.save_png(saida)
	quit()


func _cena(vp: SubViewport, modelo: String, pe: Array) -> void:
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.34, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.62)
	CarroBloco.reflexo(env)
	amb.environment = env
	mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.8, 0.7, 0)
	luz.light_energy = 1.2
	mundo.add_child(luz)
	var carro := CarroEpoca.construir(modelo, pe[0], pe[1])
	mundo.add_child(carro)
	var cam := Camera3D.new()
	cam.fov = 30.0
	mundo.add_child(cam)
	cam.look_at_from_position(Vector3(6.2, 2.4, 6.6), Vector3(0, 0.75, 0.1))
