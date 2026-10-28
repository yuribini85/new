class_name IdleUI
extends RefCounted
## Peças de interface do The Fastfather (docs/idle/plano.md), com a
## identidade do Chrome & Wreckage: cores da interface (Aba), fontes
## (Tipografia) e a arte de res://arte/ui/.

## Paleta "Noir Industrial 1937" (aprovada pelo usuário, 2026-10-28;
## docs/idle/identidade_fastfather.md, seção 16): carvão nos fundos (72%),
## petróleo nos painéis e aço nos neutros (16%), destaques (12%) em latão
## (dinheiro e conquistas), vinho (trapaças e alerta) e verde militar
## (melhorias). Os tons "claro" são os mesmos com contraste ≥ 4,5:1 sobre o
## carvão, para texto e números; o verde do botão de compra é o militar
## clareado, com texto em carvão (5,9:1).
const COR_CARVAO := Color("1c2021")
const COR_PETROLEO := Color("303f40")
const COR_ACO := Color("69716b")
const COR_MARFIM := Color("e0d6bc")
const COR_COURO := Color("76543e")
const COR_LATAO := Color("b4945d")
const COR_VINHO := Color("a7463a")
const COR_VERDE_MILITAR := Color("546c55")
const COR_ACO_CLARO := Color("98a099")  # 6,1:1
const COR_LATAO_CLARO := Color("d9c08c")  # 9,3:1
const COR_VINHO_CLARO := Color("d88577")  # 5,9:1 (4,7 no cartão)
const COR_VERDE_CLARO := Color("9cb896")  # 7,6:1
const COR_VERDE_BOTAO := Color("86a382")  # texto em carvão: 5,9:1

const COR_FUNDO := COR_CARVAO
const COR_CARTAO := Color("263234")  # entre o carvão e o petróleo
const COR_CARTAO_CLARO := COR_PETROLEO
const COR_BORDA := Color("4a5a5b")  # petróleo clareado: separa painel e fundo
const COR_CROMO := COR_ACO_CLARO  # texto secundário
const COR_TEXTO := COR_MARFIM
const COR_OURO := COR_LATAO
const COR_OURO_ESCURO := Color("7d6640")
const COR_OURO_CLARO := COR_LATAO_CLARO
const COR_DINHEIRO := COR_OURO_CLARO
const COR_GANHO := COR_VERDE_CLARO
const COR_SECUNDARIA := COR_CROMO
const COR_BLOQUEADO := COR_ACO
const COR_RUIM := COR_VINHO
const COR_BOTAO := COR_OURO
const COR_TINTA := COR_CARVAO  # texto sobre latão e verde
## Botão de anúncio premiado (▶ na TV): verde militar com texto em marfim,
## diferente do verde claro do botão de compra.
const COR_PREMIO := COR_VERDE_MILITAR
## Fluorescente (pedido do usuário, 2026-10-28): o jogo é dessaturado, então o
## que se toca e o que importa acende como letreiro de neon da época — âmbar
## para botões de ação e o prêmio, verde para o que dá para comprar e o que se
## ganha na pista. Texto em carvão por cima (contraste ≥ 10:1). Usar pouco: só
## o que é clicável ou decisivo.
const COR_NEON := Color("ffc933")
const COR_NEON_ESCURO := Color("a8781a")
const COR_NEON_VERDE := Color("a8ff5e")
const COR_NEON_VERDE_ESCURO := Color("5c9a2c")
const COR_PREMIO_ESCURO := Color("3b4d3c")


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
	# Cantos chanfrados, como as placas e molduras art déco dos anos 1930
	# (The Fastfather, docs/idle/identidade_fastfather.md).
	sb.corner_detail = 1
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


## O cabeçalho comum das abas (coesão das telas, sugestão 5 aprovada,
## 2026-10-28): painel com a moldura art déco, o ícone da folha à esquerda e o
## título no letreiro. Devolve a coluna do texto, para o subtítulo.
static func cabecalho(titulo: String, icone_nome: String, pai: Node) -> VBoxContainer:
	var p := painel(COR_CARTAO, 12, 14, pai)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = icone_hud(icone_nome)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	ic.custom_minimum_size = Vector2(60, 60)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	rotulo(titulo, 32, COR_OURO_CLARO, v, "deco")
	p.add_child(MolduraDeco.new(4.0))
	return v


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
	b.add_theme_stylebox_override("normal", brilho(_bisel(COR_NEON, COR_OURO_CLARO, COR_NEON_ESCURO), COR_NEON))
	b.add_theme_stylebox_override("hover", brilho(_bisel(COR_NEON, COR_OURO_CLARO, COR_NEON_ESCURO), COR_NEON))
	b.add_theme_stylebox_override("pressed", _bisel(COR_NEON.darkened(0.15), COR_OURO_CLARO, COR_NEON.darkened(0.15)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, COR_TINTA)


## Botão cromado (vídeos com recompensa): prata em relevo.
static func estilo_cromo(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _bisel(COR_CROMO, Color.WHITE, COR_ACO))
	b.add_theme_stylebox_override("hover", _bisel(COR_CROMO, Color.WHITE, COR_ACO))
	b.add_theme_stylebox_override("pressed", _bisel(COR_CROMO.darkened(0.12), Color.WHITE, COR_CROMO.darkened(0.12)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, COR_TINTA)


## O halo de neon em volta de um botão aceso.
static func brilho(sb: StyleBoxFlat, cor: Color) -> StyleBoxFlat:
	if Preferencias.efeitos_leves:
		return sb  # gráficos leves: sem o halo
	sb.shadow_color = Color(cor, 0.38)
	sb.shadow_size = 9
	return sb


## Fundo com a borda de baixo mais escura: o botão parece em relevo.
static func _bisel(fundo: Color, _luz: Color, sombra: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.set_corner_radius_all(12)
	sb.corner_detail = 1  # chanfro de latão (art déco)
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
## Nomes de pista próprios do The Fastfather (EUA, anos 30); o resto vem do Aba.
const NOMES_PISTA := {"estrada_das_araucarias": "Estrada dos Pinheiros"}


static func nome_pista(id: String) -> String:
	return String(NOMES_PISTA.get(id, Aba.nome_pista(id)))


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

## Ícone do HUD da arte do usuário (arte/fastfather/icones/hud, recortados da
## folha "ícones para atualizar todo o HUD"); null se não houver.
static func icone_hud(nome: String) -> Texture2D:
	var caminho := "res://arte/fastfather/icones/hud/%s.png" % nome
	return load(caminho) if ResourceLoader.exists(caminho) else null


static func busto_piloto(id: String) -> Texture2D:
	var caminho := "res://arte/pilotos/corpo/%s.webp" % id
	if not ResourceLoader.exists(caminho):
		return retrato_piloto(id)
	return busto_de(caminho)


## O mesmo recorte para qualquer arte de corpo inteiro (os rapazes da família).
## `alto`: a altura do recorte em lados (1 = quadrado; mais, desce pelo corpo).
static func busto_de(caminho: String, alto := 1.0) -> Texture2D:
	var chave := "%s|%s" % [caminho, alto]
	if _bustos.has(chave):
		return _bustos[chave]
	if caminho == "" or not ResourceLoader.exists(caminho):
		return null
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
	at.region = Rect2(x0, y0, lado, minf(lado * alto, h - y0))
	_bustos[chave] = at
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
