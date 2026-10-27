class_name IdleUI
extends RefCounted
## Peças de interface do Chrome Racing Team (docs/idle/plano.md), com a
## identidade do Chrome & Wreckage: cores da interface (Aba), fontes
## (Tipografia) e a arte de res://arte/ui/.

## Paleta "cromo + ouro", tirada do logotipo (decisão do usuário, 2026-10-24):
## fundo preto azulado, cartões em aço escuro com borda cromada, ações em ouro
## alaranjado, prata no texto secundário, dinheiro em ouro claro; verde só no
## ganho de uma melhoria; vermelho só no alerta.
const COR_FUNDO := Color("0b0e13")
const COR_CARTAO := Color("161b22")
const COR_CARTAO_CLARO := Color("1d232c")
const COR_BORDA := Color("3a4250")  # cromo escuro
const COR_CROMO := Color("c9ced6")  # prata
const COR_TEXTO := Color("f2f4f7")
const COR_OURO := Color("ffc53d")
const COR_OURO_ESCURO := Color("f08a0c")
const COR_OURO_CLARO := Color("ffd873")
const COR_DINHEIRO := COR_OURO_CLARO
const COR_GANHO := Color("6fd08c")
const COR_SECUNDARIA := COR_CROMO
const COR_BLOQUEADO := Color("5a6270")
const COR_RUIM := Color("e5484d")
const COR_BOTAO := COR_OURO
const COR_TINTA := Color("14100a")  # texto sobre ouro e prata
## Verde dos botões de anúncio premiado (▶ na TV): o padrão do gênero para
## "ganhe de graça assistindo", que o jogador reconhece de outros idles.
const COR_PREMIO := Color("2fbf6b")
const COR_PREMIO_ESCURO := Color("1b8a49")


## Tamanho de texto legível no celular (docs/idle/interface.md): a base do jogo
## tem 720 px de largura e cabe em ~360 dp, então 1 px da base vale ~0,5 dp. O
## mínimo da tela é TEXTO_MIN (24 px ≈ 12 sp, o mínimo do Android); o resto sobe
## na mesma proporção para o texto corrido ficar em 14–17 sp. Todo texto do jogo
## passa por aqui (rotulo, botao, botao_premio).
const TEXTO_MIN := 24
## Alvo de toque mínimo: 96 px ≈ 48 dp (Android) / 44 pt (iOS).
const ALTURA_MIN := 96


static func legivel(tamanho: int) -> int:
	if tamanho <= 30:
		return maxi(TEXTO_MIN, roundi(tamanho * 1.3))
	return tamanho + 8 if tamanho <= 44 else tamanho + 4


static func rotulo(texto: String, tamanho: int, cor: Color, pai: Node = null, peso := "semibold") -> Label:
	var l := Label.new()
	l.text = texto
	Tipografia.rotulo(l, peso, legivel(tamanho))
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pai != null:
		pai.add_child(l)
	return l


static func caixa(cor: Color, raio: int, margem := 12, borda := Color.TRANSPARENT, largura_borda := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(raio)
	sb.set_content_margin_all(margem)
	if largura_borda > 0:
		sb.border_color = borda
		sb.set_border_width_all(largura_borda)
	return sb


static func painel(cor := COR_CARTAO, raio := 14, margem := 12, pai: Node = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", caixa(cor, raio, margem, COR_BORDA, 1))
	if pai != null:
		pai.add_child(p)
	return p


static func icone(nome: String, tamanho: int, pai: Node = null, cor := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Aba.icone_reduzido(nome, tamanho)
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.custom_minimum_size = Vector2(tamanho, tamanho)
	t.modulate = cor
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pai != null:
		pai.add_child(t)
	return t


## Imagem que cobre a área sem esticar (escala uniforme, corta as bordas).
static func imagem_cobrindo(tex: Texture2D, altura: float, pai: Node = null, escurecer := 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = Vector2(0, altura)
	t.clip_contents = true
	t.modulate = Color(escurecer, escurecer, escurecer)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pai != null:
		pai.add_child(t)
	return t


static func botao(texto: String, cor: Color, tamanho := 24, altura := 64, pai: Node = null) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_primaria(b, texto, cor, COR_TINTA, legivel(tamanho), maxi(altura, ALTURA_MIN))
	if cor == COR_CROMO:
		estilo_cromo(b)
	else:
		estilo_ouro(b)
	desativado_legivel(b)
	if pai != null:
		pai.add_child(b)
	return b


## Botão de anúncio premiado, no padrão do gênero (docs/idle/interface.md, 5): verde, em
## duas partes. À esquerda um selo mais escuro com o ícone grande do vídeo e a
## palavra VÍDEO (o jogador sabe que é anúncio antes de tocar, como a política do
## AdMob pede); à direita a recompensa ("PRÊMIO x2", "COLETAR x2"). O texto da
## recompensa muda com texto_premio().
static func botao_premio(texto: String, tamanho := 24, altura := 64, pai: Node = null) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var alto := maxi(altura, ALTURA_MIN)
	Tipografia.acao_primaria(b, "", COR_PREMIO, Color.WHITE, legivel(tamanho), alto)
	estilo_premio(b)
	desativado_legivel(b)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_top = 6
	h.offset_right = -6
	h.offset_bottom = -10  # o bisel embaixo
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var selo := PanelContainer.new()
	selo.add_theme_stylebox_override("panel", caixa(COR_PREMIO_ESCURO, 10, 8))
	selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(selo)
	var sv := VBoxContainer.new()
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", -2)
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selo.add_child(sv)
	var icone := TextureRect.new()
	var lado := clampi(alto - 52, 30, 48)
	icone.texture = icone_video(lado)
	icone.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icone.custom_minimum_size = Vector2(lado, lado)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(icone)
	var palavra := rotulo("VÍDEO", 18, Color.WHITE, sv, "semibold")
	palavra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var r := rotulo(texto, tamanho, Color.WHITE, h, "semibold")
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.set_meta("premio", r)
	b.set_meta("selo", selo)
	if pai != null:
		pai.add_child(b)
	return b


## Troca o texto da recompensa do botão de anúncio (botao_premio).
static func texto_premio(b: Button, texto: String) -> void:
	(b.get_meta("premio") as Label).text = texto


static func estilo_premio(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _bisel(COR_PREMIO, Color.WHITE, COR_PREMIO_ESCURO))
	b.add_theme_stylebox_override("hover", _bisel(COR_PREMIO, Color.WHITE, COR_PREMIO_ESCURO))
	b.add_theme_stylebox_override("pressed", _bisel(COR_PREMIO.darkened(0.12), Color.WHITE, COR_PREMIO.darkened(0.12)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("icon_normal_color", Color.WHITE)


static var _icones_video := {}

## O ▶ na TV (arte/idle/icone_video.png), no tamanho pedido (escala uniforme).
static func icone_video(lado: int) -> Texture2D:
	if not _icones_video.has(lado):
		var tex: Texture2D = load("res://arte/idle/icone_video.png")
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(lado, lado, Image.INTERPOLATE_LANCZOS)
		_icones_video[lado] = ImageTexture.create_from_image(img)
	return _icones_video[lado]


## "Nv. 3": o nível, como os idles escrevem.
static func nv(n: int) -> String:
	return "Nv. %d" % n


## Botão de ação em ouro em relevo (borda de baixo escura), como as letras do
## logotipo; pressionado, afunda.
static func estilo_ouro(b: Button) -> void:
	var meio := COR_OURO.lerp(COR_OURO_ESCURO, 0.45)
	b.add_theme_stylebox_override("normal", _bisel(meio, COR_OURO_CLARO, Color("b5620a")))
	b.add_theme_stylebox_override("hover", _bisel(meio, COR_OURO_CLARO, Color("b5620a")))
	b.add_theme_stylebox_override("pressed", _bisel(meio.darkened(0.12), COR_OURO_CLARO, meio.darkened(0.12)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, COR_TINTA)


## Botão cromado (vídeos com recompensa): prata em relevo.
static func estilo_cromo(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _bisel(COR_CROMO, Color.WHITE, Color("7b8494")))
	b.add_theme_stylebox_override("hover", _bisel(COR_CROMO, Color.WHITE, Color("7b8494")))
	b.add_theme_stylebox_override("pressed", _bisel(COR_CROMO.darkened(0.12), Color.WHITE, COR_CROMO.darkened(0.12)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, COR_TINTA)


## Fundo com a borda de baixo mais escura: o botão parece em relevo.
static func _bisel(fundo: Color, _luz: Color, sombra: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.set_corner_radius_all(12)
	sb.border_color = sombra
	sb.border_width_bottom = 5
	sb.set_content_margin_all(8)
	sb.anti_aliasing = true
	return sb


## Desativado (sem dinheiro, relógio do contrato): placa escura com borda e
## texto claro, para o preço e o relógio continuarem legíveis.
static func desativado_legivel(b: Button) -> void:
	b.add_theme_stylebox_override("disabled", caixa(COR_CARTAO_CLARO, 12, 8, COR_BORDA, 2))
	b.add_theme_color_override("font_disabled_color", COR_CROMO.darkened(0.15))
	# Tocar no botão apagado dá um "tuc" grave (sem vibrar): o toque foi ouvido.
	b.gui_input.connect(func(e: InputEvent):
		var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed)
		if toque and b.disabled:
			Sons.tocar_ui(b, "nao", -10.0))


## Barra de rolagem fina, em ocre apagado (a cinza do Godot destoa).
static func rolagem_fina(sc: ScrollContainer) -> void:
	var barra := sc.get_v_scroll_bar()
	barra.custom_minimum_size.x = 6
	var trilho := StyleBoxEmpty.new()
	barra.add_theme_stylebox_override("scroll", trilho)
	barra.add_theme_stylebox_override("scroll_focus", trilho)
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		barra.add_theme_stylebox_override(st, caixa(Color(COR_OURO, 0.45), 3, 0))


## Pulso curto de escala no controle (compra, contrato): o toque respondeu.
## Compra feita: o botão afunda e salta, com um clarão dourado por cima.
static func premiar(b: Control) -> void:
	if Preferencias.reduzir_animacoes:
		return
	b.pivot_offset = b.size * 0.5
	var clarao: ColorRect = b.get_node_or_null("Clarao")
	if clarao == null:
		clarao = ColorRect.new()
		clarao.name = "Clarao"
		clarao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(clarao)
	clarao.color = Color(1.0, 0.86, 0.5, 0.55)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(0.9, 0.9), 0.06)
	tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(clarao, "color:a", 0.0, 0.45)


## Número que salta no lugar (o dinheiro do topo quando entra ou sai valor):
## escala > 1 cresce e volta com um quique; < 1 afunda e volta.
static func saltar(l: Control, escala := 1.15) -> void:
	if Preferencias.reduzir_animacoes:
		return
	l.pivot_offset = Vector2(0.0, l.size.y * 0.5) if l is Label and (l as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT \
			else l.size * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(escala, escala), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func pulsar(c: Control, escala := 1.06) -> void:
	if Preferencias.reduzir_animacoes:
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(escala, escala), 0.07)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12)


## Banner da pista (arte/ui/banner_*), com o tema da pista longa quando a
## curta não tem o dela.
static func banner_pista(pista_id: String) -> Texture2D:
	var tex := Aba.arte("banner_" + String(Corrida3D.TEMA_DE.get(pista_id, pista_id)))
	if tex == null:
		tex = Aba.arte("banner_arena_" + pista_id)
	return tex if tex != null else Aba.arte("fundo_competicoes")


static func retrato_piloto(id: String) -> Texture2D:
	var caminho := "res://arte/pilotos/%s.webp" % id
	return load(caminho) if ResourceLoader.exists(caminho) else null


## Busto do piloto recortado da arte de corpo inteiro (arte/pilotos/corpo/):
## quadrado com a cabeça inteira no alto, centrado nela. O retrato de rosto vem
## cortado em cima e à esquerda.
static var _bustos := {}

static func busto_piloto(id: String) -> Texture2D:
	if _bustos.has(id):
		return _bustos[id]
	var caminho := "res://arte/pilotos/corpo/%s.webp" % id
	if not ResourceLoader.exists(caminho):
		return retrato_piloto(id)
	var tex: Texture2D = load(caminho)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var topo := 0
	while topo < h - 1 and not _linha_visivel(img, topo):
		topo += 1
	# Centro da cabeça: média das colunas visíveis logo abaixo do topo.
	var soma := 0.0
	var n := 0
	for y in range(topo + int(h * 0.03), mini(topo + int(h * 0.12), h)):
		for x in range(0, w, 2):
			if img.get_pixel(x, y).a > 0.5:
				soma += x
				n += 1
	var cx := soma / n if n > 0 else w * 0.5
	var lado := w * 0.5
	var x0 := clampf(cx - lado * 0.5, 0.0, w - lado)
	var y0 := maxf(topo - lado * 0.04, 0.0)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(x0, y0, lado, lado)
	_bustos[id] = at
	return at


static func _linha_visivel(img: Image, y: int) -> bool:
	for x in range(0, img.get_width(), 2):
		if img.get_pixel(x, y).a > 0.5:
			return true
	return false


## 1234 -> "1,2 mil"; 3 400 000 -> "3,4 mi" (o jogador lê rápido).
static func curto(v: float) -> String:
	var sufixos := ["", " mil", " mi", " bi", " tri", " qua", " qui", " sx"]
	var k := 0
	while absf(v) >= 1000.0 and k < sufixos.size() - 1:
		v /= 1000.0
		k += 1
	if k == 0:
		return ("%.1f" % v).replace(".", ",").trim_suffix(",0") if absf(v) < 10.0 else str(int(v))
	return ("%.1f" % v).replace(".", ",") + sufixos[k]


## "3:12:05" / "12:05".
static func relogio(s: float) -> String:
	var t := maxi(ceili(s), 0)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60] if t >= 3600 else "%d:%02d" % [t / 60, t % 60]
