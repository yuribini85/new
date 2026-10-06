extends SceneTree
## Gera os sprites provisórios dos carros a partir do carro em código
## (CarroBloco), nas duas vistas da arte final (docs/arte_carros.md):
##   res://arte/carros/<id>_topo.png  de cima, frente para cima
##   res://arte/carros/<id>_iso.png   isométrico 2:1, frente para baixo à esquerda
## Escala fixa (PX_POR_M) para todos os carros; fundo transparente; sem sombra
## (o jogo desenha a sombra). A arte final substitui estes arquivos, um a um.
## Uso (precisa de display): godot --path . --script res://tools/gerar_sprites.gd

const PASTA := "res://arte/carros/"
const PX_POR_M := 160.0
## Tela do isométrico (px): cabe o maior carro na diagonal.
const TELA_ISO := Vector2i(1120, 800)


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var d: Node = root.get_node("Dados")
	for b in d.lista("carros"):
		var forma := CarroBloco.forma(b)
		var c: float = forma["c"]
		var l: float = forma["l"]
		var topo := Vector2i(int(ceil((l + 0.5) * PX_POR_M)), int(ceil((c + 0.4) * PX_POR_M)))
		await _foto(b, PASTA + "%s_topo.png" % b["id"], topo, true)
		await _foto(b, PASTA + "%s_iso.png" % b["id"], TELA_ISO, false)
		print("%s: topo %dx%d, iso %dx%d" % [b["id"], topo.x, topo.y, TELA_ISO.x, TELA_ISO.y])
	quit()


func _foto(base: Dictionary, caminho: String, tamanho: Vector2i, de_cima: bool) -> void:
	var vp := SubViewport.new()
	vp.size = tamanho
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.8)
	amb.environment = env
	mundo.add_child(amb)
	# Luz da especificação: de cima e da esquerda da tela, a mesma nas duas vistas.
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-1.0, -0.6, 0)
	luz.light_energy = 1.1
	mundo.add_child(luz)
	var carro := CarroBloco.new()
	mundo.add_child(carro)
	carro.configurar_modelo(base, CarroBloco.cor_do_id(base["id"]))
	var sombra := carro.get_node_or_null("Sombra")
	if sombra != null:
		sombra.visible = false  # a sombra é do jogo, não do sprite
	# O modelo aponta para +X. Topo: frente para -Z (cima da tela). Iso: frente
	# para +Z, que a câmera da corrida mostra para baixo e à esquerda.
	carro.rotation.y = PI / 2.0 if de_cima else -PI / 2.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = tamanho.y / PX_POR_M
	cam.far = 100.0
	mundo.add_child(cam)
	if de_cima:
		cam.look_at_from_position(Vector3(0, 30, 0), Vector3.ZERO, Vector3(0, 0, -1))
	else:
		# Mesma direção da câmera da corrida (2:1): (70, 57.15, 70).
		cam.look_at_from_position(Vector3(70, 57.15, 70).normalized() * 30.0 + Vector3(0, 0.6, 0), Vector3(0, 0.6, 0))
	root.add_child(vp)
	for k in 3:
		await process_frame
	vp.get_texture().get_image().save_png(caminho)
	vp.queue_free()
