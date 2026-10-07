class_name Pintura
extends Node
## Sprites de carroceria branca repintados na cor pedida (visual/shaders/pintura.gdshader).
## Cada (modelo, vista, cor) é pintado uma vez num SubViewport 2D, copiado para
## uma textura comum (com mipmaps, como os sprites importados) e o viewport sai.
## Até a cópia, a textura mostra o sprite branco original.
## Quais sprites são brancos e a faixa de brilho da pintura de cada um vêm de
## arte/carros/pintura.json (tools/medir_pintura.gd); fora dele, o sprite fica como é.

const ARQUIVO := "res://arte/carros/pintura.json"

static var _no: Pintura
static var _faixas := {}
static var _faixas_lidas := false
var _cache := {}


## Faixa de brilho da pintura [v_lo, v_med, v_ref] do sprite; vazio se não é branco.
static func faixa(id: String, vista: String) -> Array:
	if not _faixas_lidas:
		_faixas_lidas = true
		if FileAccess.file_exists(ARQUIVO):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
			if d is Dictionary:
				_faixas = d
	return _faixas.get(id, {}).get(vista, [])


static func pintavel(id: String) -> bool:
	return not faixa(id, "iso").is_empty()


## Sprite da vista na cor; o original se o modelo não tem carroceria branca.
static func textura(id: String, vista: String, cor: Color) -> Texture2D:
	var original := ArteCarro.textura(id, vista)
	var f := faixa(id, vista)
	if original == null or f.size() != 3:
		return original
	if _no == null or not is_instance_valid(_no):
		_no = Pintura.new()
		_no.name = "Pintura"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_no)
	return _no._pintar(id, vista, cor, original, f)


func _pintar(id: String, vista: String, cor: Color, original: Texture2D, f: Array) -> Texture2D:
	var chave := "%s|%s|%s" % [id, vista, cor.to_html(false)]
	if _cache.has(chave):
		return _cache[chave]
	var base := original.get_image()
	base.decompress()
	base.convert(Image.FORMAT_RGBA8)
	if not base.has_mipmaps():
		base.generate_mipmaps()
	var tex := ImageTexture.create_from_image(base)
	_cache[chave] = tex
	var vp := SubViewport.new()
	vp.size = original.get_size()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var s := Sprite2D.new()
	s.texture = original
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	m.shader = preload("res://visual/shaders/pintura.gdshader")
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("v_lo", float(f[0]))
	m.set_shader_parameter("v_med", float(f[1]))
	m.set_shader_parameter("v_ref", float(f[2]))
	s.material = m
	vp.add_child(s)
	add_child.call_deferred(vp)
	_copiar(vp, tex)
	return tex


func _copiar(vp: SubViewport, tex: ImageTexture) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if is_instance_valid(vp):
		var img := vp.get_texture().get_image()
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			tex.update(img)
		vp.queue_free()
