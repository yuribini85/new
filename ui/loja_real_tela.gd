class_name LojaRealTela
extends RefCounted
## Tela da loja de dinheiro real (decisão 101), no visual das Configurações:
## seção com etiqueta amarela e um cartão por produto. Pack Elite: os três
## pilotos premium lado a lado (retrato, nome, vaga), o que eles têm e o botão;
## Sem anúncios; "Restaurar compras" no pé. O preço é o da loja do aparelho:
## sem ela, o botão diz só "Comprar" e a nota avisa que as compras chegam na
## versão final. Comprado: o botão vira "Comprado" (verde, desligado).

const COR_PREMIUM := Color("e8b04a")


## `comprar(id)` e `restaurar()`: as ações do Principal (avisos e save).
static func montar(aba: Aba, v: VBoxContainer, dados: Node, jogador: Node, comprar: Callable,
		restaurar: Callable) -> void:
	v.add_theme_constant_override("separation", 10)
	if not LojaReal.disponivel():
		aba.nota("icone_info", "As compras chegam com a loja do aparelho, na versão final.", "", v)

	Configuracoes._secao(v, "PACK ELITE")
	var c := _caixa(v)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	c.add_child(fila)
	for t in ["corrida", "arena"]:
		for p in EquipeJogador.premium_do_tipo(dados, t):
			fila.add_child(_piloto(aba, p))
	for linha in ["100% em todos os atributos", "Sem cansaço: corre e luta sem descanso",
			"Ficam sempre no mercado de pilotos", "Compra única e permanente"]:
		_vantagem(aba, linha, c)
	_botao_compra(aba, c, dados, jogador, "pack_premium", comprar)

	Configuracoes._secao(v, "SEM ANÚNCIOS")
	var s := _caixa(v)
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 14)
	s.add_child(hs)
	var ic := IconeVetor.new("acelerar", Cabecalho.COR_NUMERO)
	ic.custom_minimum_size = Vector2(56, 48)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hs.add_child(ic)
	var ds := aba.rotulo(String(LojaReal.produto(dados, "sem_anuncios").get("descricao", "")), Aba.FONTE_PEQUENA + 1,
			Color.WHITE, hs)
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vantagem(aba, "Compra única e permanente", s)
	_botao_compra(aba, s, dados, jogador, "sem_anuncios", comprar)

	var r := Button.new()
	Tipografia.acao_secundaria(r, "Restaurar compras", Aba.COR_SECUNDARIA, 22, 64)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.pressed.connect(func(): restaurar.call())
	v.add_child(r)


## Cartão das Configurações com uma coluna dentro (mais respiro em cima e embaixo).
static func _caixa(v: VBoxContainer) -> VBoxContainer:
	var p := Configuracoes._cartao(v)
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	return col


## Coluna de um piloto premium: retrato com moldura dourada, nome e a vaga.
static func _piloto(aba: Aba, p: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	var moldura := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.07)
	sb.border_color = COR_PREMIUM
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	moldura.add_theme_stylebox_override("panel", sb)
	moldura.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	col.add_child(moldura)
	var t := TextureRect.new()
	t.texture = load(Assets.retrato_piloto(String(p["id"])))
	t.custom_minimum_size = Vector2(0, 220)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	moldura.add_child(t)
	var nome := Label.new()
	nome.text = String(p["nome"]).to_upper()
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(nome, "semibold", 24)
	col.add_child(nome)
	var vaga := aba.rotulo("CORRIDA" if String(p.get("tipo", "corrida")) == "corrida" else "ARENA", 18, COR_PREMIUM, col)
	vaga.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return col


static func _vantagem(aba: Aba, t: String, pai: Control) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pai.add_child(h)
	var ok := IconeVetor.new("check", COR_PREMIUM)
	ok.custom_minimum_size = Vector2(26, 26)
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ok)
	var l := aba.rotulo(t, Aba.FONTE_PEQUENA, Color(0.9, 0.9, 0.92), h)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Botão do produto: "Comprar · <preço da loja>", ou "Comprado" desligado.
static func _botao_compra(aba: Aba, pai: Control, dados: Node, jogador: Node, id: String, comprar: Callable) -> void:
	var b := Button.new()
	if LojaReal.comprado(dados, jogador, id):
		Tipografia.acao_primaria(b, "COMPRADO", Aba.COR_BOM, Color(0.08, 0.08, 0.08), 28, Tipografia.ALTURA_SECUNDARIA)
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", Color(0.08, 0.08, 0.08))
	else:
		var preco := LojaReal.preco(dados, id)
		Tipografia.acao_primaria(b, "COMPRAR" + ("  ·  " + preco if preco != "" else ""), COR_PREMIUM,
				Color(0.08, 0.08, 0.08), 28, Tipografia.ALTURA_SECUNDARIA)
		b.pressed.connect(func(): comprar.call(id))
	pai.add_child(b)
