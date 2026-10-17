class_name LojaRealTela
extends Control
## Loja de dinheiro real (decisões 101 e 102): tela cheia por cima de tudo,
## como a ficha do Grid. Fundo da garagem dos pilotos escurecido com um facho
## dourado de cima. PACK ELITE com brilho que passa; os três premium de corpo
## inteiro (o de corrida na frente, os de arena atrás), contorno dourado; os
## nomes carimbados com a vaga e a frase; as barras dos atributos contra o
## melhor piloto que o mercado oferece hoje (dados do jogo); o botão dourado
## (preço da loja do aparelho) com "Compra única · para sempre". Sem anúncios
## numa faixa mais baixa; avisos e "Restaurar compras" no pé. Entra em fases;
## com Reduzir animações, já aparece pronta. Comprado o pack: a cerimônia.

signal comprar(id: String)
signal restaurar
signal ir(aba: int)
signal fechou

const COR_PREMIUM := Color("e8b04a")
const COR_FUNDO := Color(0.035, 0.032, 0.03)
const ATRIBUTOS := [["ritmo", "RITMO"], ["consistencia", "CONSISTÊNCIA"], ["agressividade", "AGRESSIVIDADE"]]
const FASE_S := 0.12
const ABA_EQUIPE := 6

const SHADER_CONTORNO := """
shader_type canvas_item;
uniform vec4 cor : source_color = vec4(0.91, 0.69, 0.29, 1.0);
void fragment() {
	COLOR = vec4(cor.rgb, texture(TEXTURE, UV).a * cor.a);
}
"""

var _dados: Node
var _jogador: Node
var _fases: Array = []
var _barras: Array = []  # [ProgressBar, valor]
var _brilhos: Array = []


func _init(dados: Node, jogador: Node) -> void:
	_dados = dados
	_jogador = jogador
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_montar()


func _ready() -> void:
	Sons.tocar_ui(self, "porta", -8.0, 1.2)
	_entrar()


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var cena := TextureRect.new()
	cena.texture = Assets.get_asset("garagem_pilotos", "cenario")
	cena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cena.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cena.modulate = Color(0.3, 0.27, 0.24)
	cena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cena)
	var luz := Control.new()
	luz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	luz.draw.connect(_desenhar_luz.bind(luz))
	add_child(luz)

	var rolagem := ScrollContainer.new()
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(rolagem)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lado in ["left", "right"]:
		m.add_theme_constant_override("margin_" + lado, 24)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 14)
	rolagem.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	_titulo(v)
	_heroi(v)
	_nomes(v)
	_comparacao(v)
	_compra_pack(v)
	_turno_noite(v)
	_sem_anuncios(v)
	_rodape(v)

	var x := Button.new()
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(88, 88)
	x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	x.offset_left = -96
	x.offset_top = 8
	x.offset_right = -8
	x.offset_bottom = 96
	var ix := IconeVetor.new("x", Color(1, 1, 1, 0.85))
	ix.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ix.custom_minimum_size = Vector2(34, 34)
	ix.offset_left = -17
	ix.offset_top = -17
	ix.offset_right = 17
	ix.offset_bottom = 17
	ix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	x.add_child(ix)
	x.pressed.connect(sair)
	add_child(x)


func sair() -> void:
	fechou.emit()
	queue_free()


# ------------------------------------------------------------------ Partes

func _titulo(v: VBoxContainer) -> void:
	var sobre := Label.new()
	sobre.text = "LOJA"
	sobre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sobre.add_theme_font_override("font", Tipografia.fonte("mono_sb"))
	sobre.add_theme_font_size_override("font_size", 20)
	sobre.add_theme_color_override("font_color", Color(COR_PREMIUM, 0.8))
	v.add_child(sobre)
	_fases.append(sobre)
	var caixa := Control.new()
	caixa.custom_minimum_size = Vector2(0, 88)
	caixa.clip_contents = true
	v.add_child(caixa)
	var t := Label.new()
	t.text = "PACK ELITE"
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", Tipografia.fonte("display"))
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_color_override("font_color", COR_PREMIUM)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 4)
	caixa.add_child(t)
	_brilho(caixa, 0.0)
	_fases.append(caixa)
	var sub := Label.new()
	sub.text = "Três pilotos de elite para a sua equipe"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(sub, "medium", 26)
	sub.add_theme_color_override("font_color", Color(0.88, 0.86, 0.82))
	v.add_child(sub)
	_fases.append(sub)


## Os três de corpo inteiro: arena atrás nas laterais, corrida na frente.
func _heroi(v: VBoxContainer) -> void:
	var palco := Control.new()
	palco.custom_minimum_size = Vector2(0, 380)
	palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(palco)
	var arena := EquipeJogador.premium_do_tipo(_dados, "arena")
	var corrida := EquipeJogador.premium_do_tipo(_dados, "corrida")
	var lugares := []
	if arena.size() > 0:
		lugares.append([arena[0], 0.0, 0.52, 34.0, 0.72])
	if arena.size() > 1:
		lugares.append([arena[1], 0.48, 1.0, 34.0, 0.72])
	if not corrida.is_empty():
		lugares.append([corrida[0], 0.2, 0.8, 0.0, 1.0])
	for l in lugares:
		var corpo := _corpo(String(l[0]["id"]), float(l[4]))
		corpo.anchor_left = l[1]
		corpo.anchor_right = l[2]
		corpo.anchor_bottom = 1.0
		corpo.offset_top = l[3]
		palco.add_child(corpo)
		_fases.append(corpo)


func _corpo(id: String, luz: float) -> Control:
	var tex: Texture2D = Assets.get_asset(id, "corpo")
	if tex == null:
		tex = Assets.get_asset(id, "retrato")
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var contorno := TextureRect.new()
	contorno.texture = tex
	contorno.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contorno.offset_left = -6
	contorno.offset_right = 6
	contorno.offset_top = -6
	contorno.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	contorno.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sh := ShaderMaterial.new()
	sh.shader = Shader.new()
	sh.shader.code = SHADER_CONTORNO
	sh.set_shader_parameter("cor", Color(COR_PREMIUM, 0.55 * luz))
	contorno.material = sh
	contorno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(contorno)
	var t := TextureRect.new()
	t.texture = tex
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = Color(luz, luz, luz)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(t)
	return c


## Os nomes carimbados (arena, corrida, arena), com a vaga e a frase.
func _nomes(v: VBoxContainer) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	v.add_child(fila)
	var arena := EquipeJogador.premium_do_tipo(_dados, "arena")
	var corrida := EquipeJogador.premium_do_tipo(_dados, "corrida")
	var ordem := []
	if arena.size() > 0:
		ordem.append(arena[0])
	ordem.append_array(corrida.slice(0, 1))
	if arena.size() > 1:
		ordem.append(arena[1])
	for p in ordem:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		fila.add_child(col)
		var carimbo := Label.new()
		carimbo.text = String(p["nome"]).to_upper()
		carimbo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		carimbo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		carimbo.add_theme_font_override("font", Tipografia.fonte("carimbo"))
		carimbo.add_theme_font_size_override("font_size", 32)
		carimbo.add_theme_color_override("font_color", Color.WHITE)
		carimbo.rotation_degrees = -4.0
		carimbo.resized.connect(func(): carimbo.pivot_offset = carimbo.size * 0.5)
		col.add_child(carimbo)
		var vaga := Label.new()
		vaga.text = "CORRIDA" if String(p.get("tipo", "corrida")) == "corrida" else "ARENA"
		vaga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vaga.add_theme_font_override("font", Tipografia.fonte("mono_sb"))
		vaga.add_theme_font_size_override("font_size", 17)
		vaga.add_theme_color_override("font_color", COR_PREMIUM)
		col.add_child(vaga)
		if String(p.get("frase", "")) != "":
			var f := Label.new()
			f.text = "“%s”" % String(p["frase"])
			f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			Tipografia.rotulo(f, "regular", 18)
			f.add_theme_color_override("font_color", Color(0.8, 0.79, 0.76))
			col.add_child(f)
		_fases.append(col)


## Barras dos atributos: Elite (100%) contra o melhor que o mercado oferece hoje.
func _comparacao(v: VBoxContainer) -> void:
	var caixa := _caixa(v)
	var leg := HBoxContainer.new()
	leg.add_theme_constant_override("separation", 18)
	caixa.add_child(leg)
	_legenda(leg, COR_PREMIUM, "ELITE")
	_legenda(leg, Color(0.55, 0.56, 0.6), "MELHOR DO MERCADO HOJE")
	var melhor := _melhor_do_mercado()
	for a in ATRIBUTOS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		caixa.add_child(h)
		var l := Label.new()
		l.text = a[1]
		l.custom_minimum_size.x = 168
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.add_theme_font_override("font", Tipografia.fonte("mono_sb"))
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", Color(0.85, 0.84, 0.8))
		h.add_child(l)
		var duas := VBoxContainer.new()
		duas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		duas.add_theme_constant_override("separation", -4)
		h.add_child(duas)
		_barra(duas, COR_PREMIUM, 1.0, 14)
		_barra(duas, Color(0.55, 0.56, 0.6), float(melhor.get(a[0], 0.0)), 7)
	_fases.append(caixa.get_parent())


func _melhor_do_mercado() -> Dictionary:
	var r := {}
	var agora := Time.get_unix_time_from_system()
	for tipo in ["corrida", "arena"]:
		for c in EquipeJogador.oferta(_dados, _jogador, tipo, agora):
			if bool(c.get("premium", false)):
				continue
			var at := EquipeJogador.atributos(_dados, null, String(c["id"]))
			for a in ATRIBUTOS:
				var f := EquipeJogador.barra_atributo(_dados, a[0], float(at.get(a[0], 0.0)))
				r[a[0]] = maxf(float(r.get(a[0], 0.0)), f)
	return r


func _legenda(pai: Control, cor: Color, t: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pai.add_child(h)
	var q := ColorRect.new()
	q.color = cor
	q.custom_minimum_size = Vector2(18, 10)
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(q)
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Tipografia.fonte("mono"))
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.75, 0.74, 0.7))
	h.add_child(l)


func _barra(pai: Control, cor: Color, valor: float, alto: int) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pai.add_child(h)
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(0, alto)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(1, 1, 1, 0.08)
	fundo.set_corner_radius_all(3)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	cheio.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", fundo)
	b.add_theme_stylebox_override("fill", cheio)
	h.add_child(b)
	var n := Label.new()
	n.text = "%d%%" % roundi(valor * 100.0)
	n.custom_minimum_size.x = 58
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.add_theme_font_override("font", Tipografia.fonte_numero())
	n.add_theme_font_size_override("font_size", 22 if alto > 10 else 18)
	n.add_theme_color_override("font_color", cor.lightened(0.15))
	h.add_child(n)
	_barras.append([b, valor])


func _compra_pack(v: VBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	v.add_child(col)
	var caixa := Control.new()
	caixa.custom_minimum_size = Vector2(0, 100)
	col.add_child(caixa)
	var b := Button.new()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.focus_mode = Control.FOCUS_NONE
	caixa.add_child(b)
	var comprado := LojaReal.comprado(_dados, _jogador, "pack_premium")
	if comprado:
		_estilo_botao(b, Aba.COR_BOM, "COMPRADO", true)
	else:
		var preco := LojaReal.preco(_dados, "pack_premium")
		_estilo_botao(b, COR_PREMIUM, "COMPRAR" + ("  ·  " + preco if preco != "" else ""), false)
		b.pressed.connect(func(): comprar.emit("pack_premium"))
		caixa.clip_contents = true
		_brilho(caixa, 1.2)
		_pulsar(b)
	var nota := Label.new()
	nota.text = "Na equipe para sempre" if comprado else "Compra única · para sempre"
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.add_theme_font_override("font", Tipografia.fonte("mono"))
	nota.add_theme_font_size_override("font_size", 17)
	nota.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
	col.add_child(nota)
	_fases.append(col)


func _estilo_botao(b: Button, cor: Color, texto: String, apagado: bool) -> void:
	b.text = texto
	b.add_theme_font_override("font", Tipografia.fonte("display"))
	b.add_theme_font_size_override("font_size", 46)
	for e in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(e, Color(0.08, 0.07, 0.05))
	for e in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = cor.lightened(0.08) if e == "hover" else (cor.darkened(0.1) if e == "pressed" else cor)
		sb.set_corner_radius_all(14)
		sb.corner_detail = 1
		sb.set_border_width_all(3)
		sb.border_color = cor.lightened(0.45)
		sb.shadow_color = Color(cor, 0.45)
		sb.shadow_size = 0 if apagado else 18
		b.add_theme_stylebox_override(e, sb)
	b.disabled = apagado


## Faixas baixas, depois do pack: Turno da Noite (horas de renda offline, com
## o antes e depois do jogador) e Sem anúncios.
func _turno_noite(v: VBoxContainer) -> void:
	var p := LojaReal.produto(_dados, "turno_noite")
	if p.is_empty():
		return
	var agora_h := roundi(GestaoEquipe.teto_offline(_dados, _jogador) / 3600.0)
	var extra := roundi(float(p.get("horas_offline", 0)))
	var desc := ("Sua renda offline: %d h. Contratos de patrocínio duram %d h a mais." % [agora_h, extra]) \
			if LojaReal.comprado(_dados, _jogador, "turno_noite") \
			else "+%d h de renda offline, para sempre: %d h → %d h. Contratos duram mais." % [extra, agora_h, agora_h + extra]
	_faixa_produto(v, "turno_noite", "cronometro", String(p.get("nome", "")).to_upper(), desc)


func _sem_anuncios(v: VBoxContainer) -> void:
	_faixa_produto(v, "sem_anuncios", "acelerar", "SEM ANÚNCIOS", "Acelera as corridas sem vídeo. Compra única.")


func _faixa_produto(v: VBoxContainer, id: String, icone: String, titulo: String, texto: String) -> void:
	var caixa := _caixa(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	caixa.add_child(h)
	var ic := IconeVetor.new(icone, Cabecalho.COR_NUMERO)
	ic.custom_minimum_size = Vector2(48, 42)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var t := VBoxContainer.new()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_constant_override("separation", 0)
	h.add_child(t)
	var nome := Label.new()
	nome.text = titulo
	nome.add_theme_font_override("font", Tipografia.fonte("display_eb"))
	nome.add_theme_font_size_override("font_size", 30)
	nome.add_theme_color_override("font_color", Color.WHITE)
	t.add_child(nome)
	var d := Label.new()
	d.text = texto
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(d, "regular", 20)
	d.add_theme_color_override("font_color", Color(0.8, 0.79, 0.76))
	t.add_child(d)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(170, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	if LojaReal.comprado(_dados, _jogador, id):
		_estilo_botao(b, Aba.COR_BOM, "COMPRADO", true)
	else:
		var preco := LojaReal.preco(_dados, id)
		_estilo_botao(b, Cabecalho.COR_NUMERO, preco if preco != "" else "COMPRAR", false)
		b.pressed.connect(func(): comprar.emit(id))
	b.add_theme_font_size_override("font_size", 26)
	_fases.append(caixa.get_parent())


func _rodape(v: VBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	v.add_child(col)
	if not LojaReal.disponivel():
		var n := Label.new()
		n.text = "As compras chegam com a loja do aparelho, na versão final."
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.add_theme_font_override("font", Tipografia.fonte("mono"))
		n.add_theme_font_size_override("font_size", 15)
		n.add_theme_color_override("font_color", Color(0.6, 0.59, 0.56))
		col.add_child(n)
	var r := Button.new()
	r.flat = true
	r.focus_mode = Control.FOCUS_NONE
	r.text = "Restaurar compras"
	r.custom_minimum_size = Vector2(0, 56)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Tipografia.rotulo(r, "medium", 22)
	r.add_theme_color_override("font_color", Color(0.75, 0.74, 0.7))
	r.pressed.connect(func(): restaurar.emit())
	col.add_child(r)
	_fases.append(col)


## Cartão escuro translúcido de borda dourada fina; devolve a coluna de dentro.
func _caixa(v: VBoxContainer) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.055, 0.05, 0.82)
	sb.border_color = Color(COR_PREMIUM, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	v.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	return col


# ------------------------------------------------------------------ Efeitos

## Facho de luz dourada de cima e vinheta escura nas bordas.
func _desenhar_luz(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var topo := PackedVector2Array([Vector2(w * 0.38, 0), Vector2(w * 0.62, 0), Vector2(w * 0.95, h * 0.62),
			Vector2(w * 0.05, h * 0.62)])
	c.draw_polygon(topo, PackedColorArray([Color(COR_PREMIUM, 0.16), Color(COR_PREMIUM, 0.16),
			Color(COR_PREMIUM, 0.0), Color(COR_PREMIUM, 0.0)]))
	for i in 6:
		var a := 0.07 * (6 - i) / 6.0
		var m := float(i) * 18.0
		c.draw_rect(Rect2(0, h - 160 + m, w, 160 - m), Color(0, 0, 0, a))


## Reflexo que atravessa `c` (clip_contents ligado) a cada poucos segundos.
func _brilho(c: Control, atraso: float) -> void:
	var b := Control.new()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("t", -atraso)
	b.draw.connect(func():
		var t := float(b.get_meta("t"))
		var ciclo := 3.2
		var f := fposmod(t, ciclo) / 1.1  # 0..1 passa; depois espera
		if t < 0.0 or f > 1.0:
			return
		var w := b.size.x
		var h := b.size.y
		var x := lerpf(-0.3 * w, 1.3 * w, f)
		var larg := 70.0
		var incl := h * 0.6
		b.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + larg, 0),
				Vector2(x + larg - incl, h), Vector2(x - incl, h)]), Color(1, 0.97, 0.85, 0.32)))
	c.add_child(b)
	_brilhos.append(b)


func _process(delta: float) -> void:
	if Preferencias.reduzir_animacoes:
		return
	for b in _brilhos:
		if is_instance_valid(b):
			b.set_meta("t", float(b.get_meta("t")) + delta)
			b.queue_redraw()


func _pulsar(b: Button) -> void:
	if Preferencias.reduzir_animacoes:
		return
	var tw := b.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "modulate", Color(1.12, 1.08, 0.98), 0.9)
	tw.tween_property(b, "modulate", Color.WHITE, 0.9)


## Entrada em fases (cada parte sobe e aparece) e as barras enchem.
func _entrar() -> void:
	if Preferencias.reduzir_animacoes:
		for b in _barras:
			(b[0] as ProgressBar).value = b[1]
		return
	for i in _fases.size():
		var c: Control = _fases[i]
		c.modulate.a = 0.0
		var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(FASE_S * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.3)
	var tb := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for b in _barras:
		tb.tween_property(b[0], "value", b[1], 0.9).set_delay(FASE_S * _fases.size() * 0.6)


# ------------------------------------------------------------------ Cerimônia

## Depois da compra do pack: a tela escurece, os três entram, o carimbo ELITE
## bate e "Bem-vindos à equipe"; "Ver pilotos" leva à Equipe.
func cerimonia() -> void:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(c)
	var escuro := ColorRect.new()
	escuro.color = Color(0.02, 0.018, 0.015, 0.97)
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(escuro)
	var palco := Control.new()
	palco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palco.offset_top = 180
	palco.offset_bottom = -330
	palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(palco)
	var corpos := []
	var arena := EquipeJogador.premium_do_tipo(_dados, "arena")
	var corrida := EquipeJogador.premium_do_tipo(_dados, "corrida")
	var lugares := []
	if arena.size() > 0:
		lugares.append([arena[0], 0.0, 0.52, 40.0, 0.75])
	if arena.size() > 1:
		lugares.append([arena[1], 0.48, 1.0, 40.0, 0.75])
	if not corrida.is_empty():
		lugares.append([corrida[0], 0.18, 0.82, 0.0, 1.0])
	for l in lugares:
		var k := _corpo(String(l[0]["id"]), float(l[4]))
		k.anchor_left = l[1]
		k.anchor_right = l[2]
		k.anchor_bottom = 1.0
		k.offset_top = l[3]
		palco.add_child(k)
		corpos.append(k)
	var titulo := Label.new()
	titulo.text = "BEM-VINDOS À EQUIPE"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	titulo.offset_top = 90
	titulo.offset_bottom = 170
	titulo.add_theme_font_override("font", Tipografia.fonte("display"))
	titulo.add_theme_font_size_override("font_size", 58)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	c.add_child(titulo)
	var selo := Label.new()
	selo.text = "ELITE"
	selo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	selo.offset_top = -330
	selo.offset_bottom = -190
	selo.add_theme_font_override("font", Tipografia.fonte("carimbo"))
	selo.add_theme_font_size_override("font_size", 130)
	selo.add_theme_color_override("font_color", COR_PREMIUM)
	selo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	selo.add_theme_constant_override("outline_size", 10)
	selo.rotation_degrees = -8.0
	c.add_child(selo)
	selo.resized.connect(func(): selo.pivot_offset = selo.size * 0.5)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	b.offset_left = 40
	b.offset_right = -40
	b.offset_top = -150
	b.offset_bottom = -50
	_estilo_botao(b, COR_PREMIUM, "VER PILOTOS", false)
	b.pressed.connect(func():
		ir.emit(ABA_EQUIPE)
		sair())
	c.add_child(b)
	if Preferencias.reduzir_animacoes:
		Sons.tocar_ui(self, "batida", -6.0)
		return
	for n in [titulo, selo, b] + corpos:
		n.modulate.a = 0.0
	escuro.modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(escuro, "modulate:a", 1.0, 0.35)
	for k in corpos:
		k.position.y += 60.0
		tw.tween_property(k, "modulate:a", 1.0, 0.3)
		tw.parallel().tween_property(k, "position:y", k.position.y - 60.0, 0.4)
	tw.tween_property(titulo, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func():
		selo.scale = Vector2(2.2, 2.2)
		Sons.tocar_ui(self, "batida", -6.0))
	tw.tween_property(selo, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(selo, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	tw.tween_property(b, "modulate:a", 1.0, 0.3)
