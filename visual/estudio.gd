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
## Largura vista na foto do modelo 3D (m): a do recorte do sprite (tela de
## 1120 × 800 px a 160 px/m, RECORTE_ISO), corrigida porque a foto (TAMANHO) é
## mais larga que o recorte e a lista encaixa as duas pela altura.
const LARGURA_FOTO_GLB_M := 1120.0 / 160.0 * 0.74 * (360.0 / 200.0) / ((1120.0 * 0.74) / (800.0 * 0.66))
## Folga em volta do carro que precisou de enquadramento próprio (fração do quadro).
const MARGEM_FOTO := 0.06
var _fotos := {}  # "id|cor" -> ViewportTexture
## Fotos guardadas no máximo (as mais recentes): cada uma tem 0,3 MB na memória
## de vídeo e passear pelas lojas juntava centenas. A que sai do cache continua
## viva enquanto alguma tela a mostra; pedida de novo, é refeita.
const FOTOS_MAX := 48
var _ordem: Array = []


## Textura da foto do modelo na pintura dada. `faixas`: as da cabine de pintura
## (faixas e número do carro do jogador); só no modelo 3D, como na vitrine.
static func foto(base: Dictionary, cor: Color, faixas: Dictionary = {}) -> Texture2D:
	if _no == null or not is_instance_valid(_no):
		_no = Estudio.new()
		_no.name = "Estudio"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_no)
	return _no._foto(base, cor, faixas)


func _foto(base: Dictionary, cor: Color, faixas: Dictionary = {}) -> Texture2D:
	var glb := CarroBloco.tem_modelo(String(base.get("id", "")))
	var arte: Texture2D = null if glb else ArteCarro.textura(String(base.get("id", "")), "iso")
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
	if not faixas.is_empty():
		chave += "|%d" % JSON.stringify(faixas, "", true).hash()
	if _fotos.has(chave):
		_usar(chave)
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
	CarroBloco.reflexo(env)  # o reflexo do verniz na pintura
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
	carro.configurar_modelo(base, cor, faixas)
	var cam := Camera3D.new()
	mundo.add_child(cam)
	if glb:
		# Modelo 3D: o ângulo e a escala dos sprites isométricos (a vitrine
		# usa os mesmos), para ficar lado a lado com os carros de arte.
		carro.rotation.y = VitrineCarro.ROTACAO_MODELO
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.size = LARGURA_FOTO_GLB_M
		cam.far = 200.0
		var alvo := Vector3(0, 0.6, 0)
		cam.transform = Transform3D(Basis.looking_at(-Vector3(70, 57.15, 70)), Vector3(70, 57.15, 70).normalized() * 40.0 + alvo)
		_enquadrar(cam, carro)
	else:
		# Enquadramento mais aberto: o carro provisório ocupa a foto na mesma
		# proporção do sprite recortado (RECORTE_ISO), lado a lado com os de arte.
		cam.fov = FOV_PROVISORIO
		cam.look_at_from_position(Vector3(4.3, 1.6, 5.8), Vector3(0, 0.5, 0))
	add_child(vp)
	# A foto vira uma textura comum e o viewport sai: centenas de carros sem
	# sprite não podem manter centenas de viewports vivos. Até a cópia, a
	# textura fica transparente (quem já a usa recebe a imagem depois).
	var tex := ImageTexture.create_from_image(Image.create(TAMANHO.x, TAMANHO.y, false, Image.FORMAT_RGBA8))
	_fotos[chave] = tex
	_usar(chave)
	_copiar(vp, tex)
	return tex


## Marca a foto como recente e tira do cache as mais antigas além de FOTOS_MAX.
func _usar(chave: String) -> void:
	_ordem.erase(chave)
	_ordem.append(chave)
	while _ordem.size() > FOTOS_MAX:
		_fotos.erase(_ordem.pop_front())


## Carro alto (utilitário, caminhão) passaria do quadro com a mira e a escala
## de todos: só então a câmera centra nele e, se ainda não couber, se afasta
## (esse carro sai menor; os outros ficam na escala comum, lado a lado).
func _enquadrar(cam: Camera3D, carro: Node3D) -> void:
	var olho_inv := cam.transform.affine_inverse()
	var mn := Vector2(INF, INF)
	var mx := -mn
	for mi: MeshInstance3D in carro.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var x := mi.transform
		var n := mi.get_parent()
		while n != null and n != carro.get_parent():
			if n is Node3D:
				x = (n as Node3D).transform * x
			n = n.get_parent()
		var b := mi.get_aabb()
		for k in 8:
			var q := olho_inv * (x * b.get_endpoint(k))
			mn = mn.min(Vector2(q.x, q.y))
			mx = mx.max(Vector2(q.x, q.y))
	if mn.x == INF:
		return
	var meio := Vector2(cam.size, cam.size * TAMANHO.y / TAMANHO.x) * 0.5 * (1.0 - MARGEM_FOTO)
	if mn.x >= -meio.x and mn.y >= -meio.y and mx.x <= meio.x and mx.y <= meio.y:
		return
	var escala := maxf(1.0, maxf((mx.x - mn.x) / (2.0 * meio.x), (mx.y - mn.y) / (2.0 * meio.y)))
	cam.size *= escala
	var centro := (mn + mx) * 0.5
	cam.transform.origin += cam.transform.basis.x * centro.x + cam.transform.basis.y * centro.y


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
static func imagem(base: Dictionary, cor: Color, tamanho := Vector2(180, 100), faixas: Dictionary = {}) -> TextureRect:
	var t := TextureRect.new()
	t.texture = foto(base, cor, faixas)
	t.custom_minimum_size = tamanho
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
