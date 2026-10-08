extends Aba
## Garagem: o carro selecionado em destaque (vitrine com o sprite isométrico) com a
## ficha por cima, como HUD, e as duas ações do caminho (preparar, correr).
## Embaixo, a coleção em miniaturas para trocar de carro.

var _vitrine: VitrineCarro


func _init(d: Node, j: Node) -> void:
	super(d, j, "Garagem")
	_vitrine = VitrineCarro.new(470.0)
	if Aba.arte("fundo_garagem") != null:
		_vitrine.fundo_imagem(Aba.arte("fundo_garagem"))
	else:
		_vitrine.ambiente_garagem()


func atualizar() -> void:
	if _vitrine.get_parent() != null:
		_vitrine.get_parent().remove_child(_vitrine)
	super()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_vitrine) and _vitrine.get_parent() == null:
		_vitrine.free()


func construir() -> void:
	var lista: Array = jogador.garagem.lista()
	_faixa_objetivo()
	if lista.is_empty():
		_vazia()
		return
	if carro_ativo() == null:
		jogador.carro_ativo = lista[0].uid
	var c := carro_ativo()
	_vitrine.mostrar_modelo(c.base, CarroBloco.cor_do_carro(c))
	ancora("CAR_STATS", _palco(c))
	var h := acoes()
	botao("Melhorar o carro", func(): ir_para.emit(OFICINA), true, true, h, "icone_melhorar")
	botao("Correr", func(): ir_para.emit(EVENTOS), true, false, h, "icone_correr")
	var sec := acoes()
	botao_texto("Ficha completa", func(): ficha_modelo(c.base), sec)
	botao_texto("Vender por %s Cr" % dinheiro(revenda(c.base)), _confirmar_venda.bind(c),
			sec, not _correndo(c) and jogador.concessionaria.pode_vender(c.uid))
	_colecao_miniaturas(lista, c)


## A vitrine com a ficha por cima, como um HUD nos cantos da ambientação:
## nome e fabricante em cima à esquerda, tração e peças à direita, os quatro
## atributos numa faixa embaixo. Libera a tela sem precisar rolar.
func _palco(c: Carro) -> Control:
	var palco := Control.new()
	palco.custom_minimum_size = _vitrine.custom_minimum_size
	palco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_child(palco)
	_vitrine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palco.add_child(_vitrine)
	var fab: Dictionary = dados.item("fabricantes", c.base["fabricante"])
	# Canto de cima, à esquerda: nome e fabricante.
	var tl := VBoxContainer.new()
	tl.position = Vector2(18, 14)
	tl.add_theme_constant_override("separation", -2)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(tl)
	_hud_rotulo(c.base["nome"], 38, Color.WHITE, tl)
	_hud_rotulo("%s%s%s" % [fab.get("nome", ""), " · %d" % c.base["ano"] if int(c.base["ano"]) > 0 else "",
			" · correndo agora" if _correndo(c) else ""], FONTE_PEQUENA, COR_SECUNDARIA, tl)
	# Canto de cima, à direita: tração e peças instaladas.
	var tr := VBoxContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -260
	tr.offset_right = -18
	tr.offset_top = 16
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(tr)
	var ht := HBoxContainer.new()
	ht.alignment = BoxContainer.ALIGNMENT_END
	ht.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(ht)
	icone(ICONE_TRACAO.get(c.base["tracao"], "icone_tracao_traseira"), 36, ht)
	_hud_rotulo(NOMES_TRACAO_CURTO.get(c.base["tracao"], c.base["tracao"]), FONTE_PEQUENA, COR_SECUNDARIA, ht)
	if not c.pecas.is_empty():
		var lp := _hud_rotulo("%d peça%s" % [c.pecas.size(), "" if c.pecas.size() == 1 else "s"], FONTE_PEQUENA,
				COR_SECUNDARIA, tr)
		lp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Faixa de baixo: os quatro atributos.
	var a := c.atributos_efetivos("seco")
	var faixa := PanelContainer.new()
	faixa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	faixa.offset_top = -86
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COR_FUNDO, 0.72)
	sb.set_content_margin_all(8)
	faixa.add_theme_stylebox_override("panel", sb)
	palco.add_child(faixa)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.add_child(h)
	for it in [["icone_potencia", "%d" % a["potencia"], "cv"], ["icone_peso", "%d" % a["peso"], "kg"],
			["icone_pneus", "%d" % roundi(a.get("aderencia", 1.0) * 100.0), "pneus"],
			["icone_freios", "%d" % roundi(a.get("freio", 1.0) * 100.0), "freios"]]:
		var cel := HBoxContainer.new()
		cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cel.alignment = BoxContainer.ALIGNMENT_CENTER
		cel.add_theme_constant_override("separation", 6)
		cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(cel)
		icone(it[0], 40, cel)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -6)
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cel.add_child(tv)
		_hud_rotulo(it[1], 30, Color.WHITE, tv)
		_hud_rotulo(it[2], FONTE_PEQUENA - 5, COR_SECUNDARIA, tv)
	return palco


## Texto do HUD: contorno escuro para ler sobre a ilustração.
func _hud_rotulo(t: String, tamanho: int, cor: Color, pai: Control) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l


func _correndo(c: Carro) -> bool:
	return not jogador.fila.is_empty() and int(jogador.fila["uid"]) == c.uid


## Garagem vazia: chamada única para escolher o primeiro carro.
func _vazia() -> void:
	if _sem_saida():
		var v := cartao(COR_RUIM)
		rotulo("Sem carro e sem dinheiro para comprar um.", 0, COR_RUIM, v)
		botao("Recomeçar carreira", _recomecar, true, true, v)
		return
	var v := cartao()
	rotulo("Sua garagem está vazia", 40, Color.WHITE, v)
	nota("icone_comprar", "Comece por um usado", "Os usados são mais baratos, e alguns já vencem a primeira corrida.", v)
	botao("Escolher meu primeiro carro", func(): ir_para.emit(LOJA), true, true, v)


## Objetivo atual numa faixa fina que leva à tela certa.
func _faixa_objetivo() -> void:
	var lista := Objetivos.lista(jogador, dados)
	var i := Objetivos.atual(lista)
	if i >= lista.size():
		return
	var b := Button.new()
	b.text = "Objetivo %d/%d · %s  ›" % [i + 1, lista.size(), lista[i]["texto"]]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", FONTE_PEQUENA + 2)
	b.add_theme_color_override("font_color", COR_INFO.lightened(0.3))
	b.clip_text = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(COR_INFO, 0.14)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, sb)
	b.pressed.connect(func():
		ir_para.emit(lista[i]["aba"])
		mudou.emit())
	conteudo.add_child(b)


## Coleção em miniaturas (fotos): tocar troca o carro em destaque.
func _colecao_miniaturas(lista: Array, ativo: Carro) -> void:
	rotulo("SUA GARAGEM · %d carro%s" % [lista.size(), "" if lista.size() == 1 else "s"], FONTE_PEQUENA, COR_SECUNDARIA)
	var rolagem := ScrollContainer.new()
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.custom_minimum_size = Vector2(0, 170)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	rolagem.add_child(h)
	for c in lista:
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 160)
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_CARTAO
		sb.set_corner_radius_all(12)
		sb.border_color = COR_DESTAQUE if c.uid == ativo.uid else Color(1, 1, 1, 0.06)
		sb.set_border_width_all(3)
		for estado in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(estado, sb)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var img := icone_carro(c.base, false, CarroBloco.cor_do_carro(c))
		img.custom_minimum_size = Vector2(180, 110)
		v.add_child(img)
		var l := Label.new()
		l.text = nome_curto(c.base["nome"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 25)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		l.custom_minimum_size.x = 180
		v.add_child(l)
		b.pressed.connect(func():
			jogador.carro_ativo = c.uid
			mudou.emit())
		h.add_child(b)
	var mais := Button.new()
	mais.text = "+\nMercado"
	mais.custom_minimum_size = Vector2(130, 160)
	mais.pressed.connect(func():
		ir_para.emit(LOJA)
		mudou.emit())
	h.add_child(mais)
	conteudo.add_child(rolagem)


func _confirmar_venda(c: Carro) -> void:
	painel.emit("Vender %s?" % c.base["nome"], func(v):
		v.add_child(Estudio.imagem(c.base, CarroBloco.cor_do_carro(c), Vector2(0, 180)))
		nota("icone_vender", "Você recebe %s Cr" % dinheiro(revenda(c.base)), "", v, Color.WHITE)
		rotulo("Peças instaladas não entram no valor.", FONTE_PEQUENA, COR_SECUNDARIA, v),
		[["Vender", func():
			_vender(c.uid)
			mudou.emit()], ["Cancelar", func(): pass]])


func _vender(uid: int) -> void:
	if not jogador.concessionaria.pode_vender(uid):
		avisar("O único carro da garagem não pode ser vendido.", false)
		return
	var nome: String = jogador.garagem.carro(uid).base["nome"]
	avisar("Vendido: %s por %s Cr." % [nome, dinheiro(jogador.concessionaria.vender_carro(uid))])
	if jogador.carro_ativo == uid:
		jogador.carro_ativo = -1


## Garagem vazia e nenhum carro (novo ou usado de hoje) cabe no saldo.
func _sem_saida() -> bool:
	var precos := []
	for c in dados.lista("carros"):
		if c.get("novo", true):
			precos.append(int(c["preco"]))
	for o in Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos):
		precos.append(int(o["preco"]))
	return precos.all(func(p): return not jogador.economia.pode_pagar(p))


func _recomecar() -> void:
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	avisar("Carreira recomeçada com %s Cr." % dinheiro(jogador.economia.saldo))
