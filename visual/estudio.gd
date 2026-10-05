class_name Estudio
extends Node
## Fotos dos carros para listas e catálogo: cada modelo (e pintura) é montado
## uma vez num SubViewport que renderiza uma só vez; a textura fica em cache.
## Imagem própria do jogo, gerada do mesmo modelo 3D da corrida.

const TAMANHO := Vector2i(360, 200)

static var _no: Estudio
var _fotos := {}  # "id|cor" -> ViewportTexture


## Textura da foto do modelo na pintura dada.
static func foto(base: Dictionary, cor: Color) -> Texture2D:
	if _no == null or not is_instance_valid(_no):
		_no = Estudio.new()
		_no.name = "Estudio"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_no)
	return _no._foto(base, cor)


func _foto(base: Dictionary, cor: Color) -> Texture2D:
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
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	amb.environment = env
	mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.8, 0.9, 0)
	luz.light_energy = 0.9
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
	cam.fov = 21
	mundo.add_child(cam)
	cam.look_at_from_position(Vector3(4.3, 1.6, 5.8), Vector3(0, 0.5, 0))
	add_child(vp)
	var tex := vp.get_texture()
	_fotos[chave] = tex
	return tex


## Retângulo com a foto, pronto para pôr numa lista.
static func imagem(base: Dictionary, cor: Color, tamanho := Vector2(180, 100)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = foto(base, cor)
	t.custom_minimum_size = tamanho
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
