extends Aba
## Garagem: o carro selecionado em destaque (vitrine com o sprite isométrico) com a
## ficha por cima, como HUD, e as ações do carro (melhorar, vender); correr fica
## na barra de baixo.
## Embaixo, a coleção em miniaturas para trocar de carro.

var _vitrine: VitrineCarro

## Apresentação da garagem (não balanceamento).
const ALTURA_ACAO := 80
const ALTURA_TEXTO_ACAO := 30


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
	# Correr fica na barra de baixo; aqui, melhorar (principal) e vender.
	var h := acoes()
	var melhorar := _acao(h, func(): ir_para.emit(OFICINA))
	Tipografia.acao_primaria(melhorar, "Melhorar o carro", COR_DESTAQUE, Color(0.1, 0.1, 0.1), ALTURA_TEXTO_ACAO, ALTURA_ACAO)
	var vender := _acao(h, _confirmar_venda.bind(c))
	vender.disabled = _correndo(c) or not jogador.concessionaria.pode_vender(c.uid)
	Tipografia.acao_neutra(vender, "Vender · %s G" % dinheiro(revenda(c.base)), ALTURA_TEXTO_ACAO - 2, ALTURA_ACAO)
	var ficha := _acao(conteudo, func(): ficha_modelo(c.base))
	Tipografia.acao_secundaria(ficha, "Ficha completa ›", COR_INFO.lightened(0.2), 26, 64)
	_colecao_miniaturas(lista, c)


## Botão de ação da garagem: executa e reconstrói (como Aba.botao), com o
## visual vindo dos tokens de Tipografia.
func _acao(pai: Control, acao: Callable) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		acao.call()
		mudou.emit())
	pai.add_child(b)
	return b


## A vitrine com a ficha por cima, como um HUD nos cantos da ambientação:
## nome e fabricante em cima à esquerda, tração e peças à direita, os quatro
## atributos embaixo (pneus e freios em relação ao de fábrica). Libera a tela
## sem precisar rolar.
func _palco(c: Carro) -> Control:
	var palco := Control.new()
	palco.custom_minimum_size = _vitrine.custom_minimum_size
	palco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_child(palco)
	_vitrine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palco.add_child(_vitrine)
	var fab: Dictionary = dados.item("fabricantes", c.base["fabricante"])
	# Cabeçalho: o nome em destaque; fabricante, ano, tração e peças numa
	# linha só, embaixo dele. O canto direito fica para a ilustração.
	var tl := VBoxContainer.new()
	tl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tl.offset_left = 20
	tl.offset_right = -20
	tl.offset_top = 12
	tl.add_theme_constant_override("separation", -4)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(tl)
	Tipografia.rotulo(_hud_rotulo(c.base["nome"], 0, Color.WHITE, tl), "semibold", 48)
	var partes: Array = [fab.get("nome", "")]
	if int(c.base["ano"]) > 0:
		partes.append(str(int(c.base["ano"])))
	partes.append(NOMES_TRACAO_CURTO.get(c.base["tracao"], c.base["tracao"]))
	if not c.pecas.is_empty():
		partes.append("%d peça%s" % [c.pecas.size(), "" if c.pecas.size() == 1 else "s"])
	if _correndo(c):
		partes.append("correndo agora")
	Tipografia.rotulo(_hud_rotulo(" · ".join(partes), 0, Color(0.86, 0.87, 0.9), tl), "medium", 26)
	# Faixa de baixo: os quatro atributos.
	var a := c.atributos_efetivos("seco")
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	h.offset_top = -82
	h.offset_bottom = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(h)
	# Pneus e freios: o ganho sobre o carro de fábrica (o modelo já tem a
	# aderência e o freio dele; "-2%" num carro sem peça pareceria defeito).
	var ganho := func(attr: String) -> float:
		return float(a.get(attr, 1.0)) / maxf(float(c.base.get(attr, 1.0) if c.base.get(attr) != null else 1.0), 1e-6)
	# Cada atributo: rótulo pequeno em caixa alta e, embaixo, valor grande e
	# unidade (sem ícone: o rótulo já diz o que é).
	for it in [["POTÊNCIA", "icone_potencia", "%d" % a["potencia"], "cv"], ["PESO", "icone_peso", "%d" % a["peso"], "kg"],
			["PNEUS", "icone_pneus", texto_fator(ganho.call("aderencia"), true), ""],
			["FREIOS", "icone_freios", texto_fator(ganho.call("freio"), true), ""]]:
		var cel := VBoxContainer.new()
		cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cel.add_theme_constant_override("separation", -2)
		cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(cel)
		var titulo := _hud_rotulo(it[0], 0, COR_SECUNDARIA, cel)
		Tipografia.rotulo(titulo, "medium", 18)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var linha := HBoxContainer.new()
		linha.alignment = BoxContainer.ALIGNMENT_CENTER
		linha.add_theme_constant_override("separation", 4)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cel.add_child(linha)
		Tipografia.rotulo(_hud_rotulo(it[2], 0, Color.WHITE, linha), "semibold", 34)
		if it[3] != "":
			var u := _hud_rotulo(it[3], 0, COR_SECUNDARIA, linha)
			Tipografia.rotulo(u, "regular", 22)
			u.size_flags_vertical = Control.SIZE_SHRINK_END
	return palco


## Texto do HUD: contorno escuro para ler sobre a ilustração.
func _hud_rotulo(t: String, tamanho: int, cor: Color, pai: Control) -> Label:
	var l := Label.new()
	l.text = t
	if tamanho > 0:
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
	# Missão ativa: uma linha discreta (filete ocre à esquerda), não um
	# segundo cabeçalho. O toque leva à tela do objetivo.
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.clip_text = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.04)
	sb.border_color = COR_DESTAQUE
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	var sb_toque := sb.duplicate()
	sb_toque.bg_color = Color(1, 1, 1, 0.1)
	for estado in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(estado, sb)
	b.add_theme_stylebox_override("pressed", sb_toque)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -12
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var n := Label.new()
	n.text = "%d/%d" % [i + 1, lista.size()]
	n.add_theme_color_override("font_color", COR_DESTAQUE)
	Tipografia.rotulo(n, "semibold", 26)
	h.add_child(n)
	var t := Label.new()
	t.text = String(lista[i]["texto"])
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	t.add_theme_color_override("font_color", Color(0.86, 0.87, 0.9))
	Tipografia.rotulo(t, "medium", 26)
	h.add_child(t)
	var seta := Label.new()
	seta.text = "›"
	seta.add_theme_color_override("font_color", COR_SECUNDARIA)
	Tipografia.rotulo(seta, "medium", 30)
	h.add_child(seta)
	for l in [n, t, seta]:
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_FILL
	b.pressed.connect(func():
		ir_para.emit(lista[i]["aba"])
		mudou.emit())
	conteudo.add_child(b)


## Coleção em miniaturas (fotos): tocar troca o carro em destaque.
func _colecao_miniaturas(lista: Array, ativo: Carro) -> void:
	Tipografia.rotulo(rotulo("SUA GARAGEM · %d CARRO%s" % [lista.size(), "" if lista.size() == 1 else "S"], 0,
			COR_SECUNDARIA), "medium", 22)
	var rolagem := ScrollContainer.new()
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.scroll_deadzone = 100000  # o arrasto é o da aba (Aba._input)
	rolagem.custom_minimum_size = Vector2(0, 170)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	rolagem.add_child(h)
	for c in lista:
		var b := Button.new()
		b.custom_minimum_size = Vector2(172, 146)
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_CARTAO
		sb.set_corner_radius_all(8)
		sb.border_color = COR_DESTAQUE if c.uid == ativo.uid else Color(1, 1, 1, 0.08)
		sb.set_border_width_all(2)
		for estado in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(estado, sb)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var img := icone_carro(c.base, false, CarroBloco.cor_do_carro(c))
		img.custom_minimum_size = Vector2(164, 100)
		v.add_child(img)
		var l := Label.new()
		l.text = nome_curto(c.base["nome"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Tipografia.rotulo(l, "medium", 24)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		l.custom_minimum_size.x = 164
		v.add_child(l)
		b.pressed.connect(func():
			jogador.carro_ativo = c.uid
			mudou.emit())
		h.add_child(b)
	conteudo.add_child(rolagem)


func _confirmar_venda(c: Carro) -> void:
	painel.emit("Vender %s?" % c.base["nome"], func(v):
		v.add_child(Estudio.imagem(c.base, CarroBloco.cor_do_carro(c), Vector2(0, 180)))
		nota("icone_vender", "Você recebe %s G" % dinheiro(revenda(c.base)), "", v, Color.WHITE)
		rotulo("Peças instaladas não entram no valor.", FONTE_PEQUENA, COR_SECUNDARIA, v),
		[["Vender", func():
			_vender(c.uid)
			mudou.emit()], ["Cancelar", func(): pass]])


func _vender(uid: int) -> void:
	if not jogador.concessionaria.pode_vender(uid):
		avisar("O único carro da garagem não pode ser vendido.", false)
		return
	var nome: String = jogador.garagem.carro(uid).base["nome"]
	avisar("Vendido: %s por %s G." % [nome, dinheiro(jogador.concessionaria.vender_carro(uid))])
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
	avisar("Carreira recomeçada com %s G." % dinheiro(jogador.economia.saldo))
