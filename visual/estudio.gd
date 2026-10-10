class_name Estudio
extends Node
## Fotos dos carros para listas e catálogo: cada modelo (e pintura) é montado
## uma vez num SubViewport que renderiza uma só vez; a imagem fica em cache
## numa textura comum e o viewport é liberado.
## Imagem própria do jogo, gerada do mesmo modelo 3D da corrida.

const TAMANHO := Vector2i(360, 200)

static var _no: Estudio
## Fração da tela do sprite isométrico que entra na foto (o maior carro cabe).
const RECORTE_ISO := Vector2(0.74, 0.66)
## Campo de visão da foto do carro provisório (3D).
const FOV_PROVISORIO := 27.0
var _fotos := {}  # "id|cor" -> ViewportTexture


## Textura da foto do modelo na pintura dada.
static func foto(base: Dictionary, cor: Color) -> Texture2D:
	if _no == null or not is_instance_valid(_no):
		_no = Estudio.new()
		_no.name = "Estudio"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_no)
	return _no._foto(base, cor)


func _foto(base: Dictionary, cor: Color) -> Texture2D:
	var arte := ArteCarro.textura(String(base.get("id", "")), "iso")
	if arte != null:
		# Decisão 31: a foto é o próprio sprite isométrico, sem a margem vazia da
		# tela. O recorte é o mesmo para todos: carro pequeno continua menor.
		var id := String(base.get("id", ""))
		# Carroceria branca: a foto é o sprite pintado na cor pedida (Pintura).
		var pintar := Pintura.pintavel(id) and cor.a > 0.0
		var chave_arte := "arte|%s|%s" % [id, cor.to_html(false) if pintar else ""]
		if not _fotos.has(chave_arte):
			var a := AtlasTexture.new()
			a.atlas = Pintura.textura(id, "iso", cor) if pintar else arte
			var tam := Vector2(arte.get_size()) * RECORTE_ISO
			a.region = Rect2(Vector2(arte.get_size()) * Vector2(0.5, 0.48) - tam * 0.5, tam)
			_fotos[chave_arte] = a
		return _fotos[chave_arte]
	var chave := "%s|%s" % [base.get("id", ""), cor.to_html(false)]
	if _fotos.has(chave):
		return _fotos[chave]
	var vp := SubViewport.new()
	vp.size = TAMANHO
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var mundo := Node3D.new()
	vp.add_child(mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.8)
	amb.environment = env
	mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.8, 0.9, 0)
	luz.light_energy = 1.05
	mundo.add_child(luz)
	# Luz de recorte por trás: carro escuro não some no fundo escuro.
	var recorte := DirectionalLight3D.new()
	recorte.rotation = Vector3(-0.35, PI + 0.5, 0)
	recorte.light_energy = 0.7
	recorte.light_color = Color(0.75, 0.85, 1.0)
	mundo.add_child(recorte)
	var carro := CarroBloco.new()
	mundo.add_child(carro)
	carro.configurar_modelo(base, cor)
	var cam := Camera3D.new()
	# Enquadramento mais aberto: o carro provisório ocupa a foto na mesma
	# proporção do sprite recortado (RECORTE_ISO), lado a lado com os de arte.
	cam.fov = FOV_PROVISORIO
	mundo.add_child(cam)
	cam.look_at_from_position(Vector3(4.3, 1.6, 5.8), Vector3(0, 0.5, 0))
	add_child(vp)
	# A foto vira uma textura comum e o viewport sai: centenas de carros sem
	# sprite não podem manter centenas de viewports vivos. Até a cópia, a
	# textura fica transparente (quem já a usa recebe a imagem depois).
	var tex := ImageTexture.create_from_image(Image.create(TAMANHO.x, TAMANHO.y, false, Image.FORMAT_RGBA8))
	_fotos[chave] = tex
	_copiar(vp, tex)
	return tex


func _copiar(vp: SubViewport, tex: ImageTexture) -> void:
	# Foto pedida antes de o estúdio entrar na árvore (ao abrir o jogo, na
	# Garagem): espera ele entrar e só então desenha uma vez.
	var arvore := Engine.get_main_loop() as SceneTree
	while is_instance_valid(vp) and not vp.is_inside_tree():
		await arvore.process_frame
	if not is_instance_valid(vp):
		return
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if is_instance_valid(vp):
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			tex.update(img)
		vp.queue_free()


## Retângulo com a foto, pronto para pôr numa lista.
static func imagem(base: Dictionary, cor: Color, tamanho := Vector2(180, 100)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = foto(base, cor)
	t.custom_minimum_size = tamanho
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
