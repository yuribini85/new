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
	if lista.is_empty():
		_faixa_objetivo()
		_vazia()
		return
	if carro_ativo() == null:
		jogador.carro_ativo = lista[0].uid
	var c := carro_ativo()
	_vitrine.mostrar_modelo(c.base, CarroBloco.cor_do_carro(c))
	ancora("CAR_STATS", _palco(c, lista))
	# O palco é o cenário do topo (colado no cabeçalho); a missão vem logo abaixo.
	_faixa_objetivo()
	# Correr fica na barra de baixo; aqui, melhorar (principal) e vender.
	var h := acoes()
	var melhorar := _acao(h, func(): ir_para.emit(OFICINA))
	Tipografia.acao_primaria(melhorar, "Oficina", COR_DESTAQUE, Color(0.1, 0.1, 0.1), ALTURA_TEXTO_ACAO, ALTURA_ACAO)
	ancora("OFICINA", melhorar)
	var vender := _acao(h, _confirmar_venda.bind(c))
	vender.disabled = _correndo(c) or not jogador.concessionaria.pode_vender(c.uid) or Prologo.carro_travado(dados, jogador, c)
	Tipografia.acao_neutra(vender, "Vender · %s G" % dinheiro(revenda(c.base)), ALTURA_TEXTO_ACAO - 2, ALTURA_ACAO)
	_evolucao(c)
	_colecao(lista, c)


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


## Todas as categorias compráveis, na ordem da seção Evolução.
const EVOLUCAO := ["aspiracao", "muffler", "computer", "intercooler", "portpolish", "enginebalance", "displacement",
		"lightweight", "corrida", "brake", "cambio"]
const NOMES_CATEGORIA := preload("res://ui/aba_oficina.gd").NOMES_CATEGORIA
## Setas da coleção: o voltar do cabeçalho com metade do tamanho.
const SETA := Vector2(Cabecalho.ALTURA * 0.95, Cabecalho.ALTURA) * 0.5


## [comprados, existentes] das peças dessas categorias para o carro.
func _progresso(c: Carro, categorias: Array) -> Array:
	var feitos := 0
	var total := 0
	for p in dados.lista("pecas"):
		if not p["categoria"] in categorias or not c.motivo_recusa(p).is_empty():
			continue
		total += 1
		if p["id"] in c.pecas_possuidas:
			feitos += 1
	return [feitos, total]


## Teto de cada número da ficha por modelo: {potencia, peso, vel} com a melhor
## peça de cada categoria (mais potência; no empate, menos peso) e o melhor
## ajuste do câmbio para a velocidade. Calculado uma vez por modelo.
static var _tetos := {}


func _tetos_do_modelo(c: Carro) -> Dictionary:
	if _tetos.has(c.id):
		return _tetos[c.id]
	var m := c.copiar()
	m.pecas = {}
	m.ajuste_cambio = ""
	var por_categoria := {}
	for p in dados.lista("pecas"):
		if c.motivo_recusa(p).is_empty():
			por_categoria.get_or_add(p["categoria"], []).append(p)
	for cat in por_categoria:
		var melhor := {}
		var nota := [-INF, INF]
		for p in por_categoria[cat]:
			m.pecas[cat] = p
			var a := m.atributos_efetivos("seco")
			if a["potencia"] > nota[0] or (a["potencia"] == nota[0] and a["peso"] < nota[1]):
				nota = [a["potencia"], a["peso"]]
				melhor = p
		m.pecas[cat] = melhor
	var a := m.atributos_efetivos("seco")
	var vel := 0.0
	for ajuste in ["", "curto", "longo"]:
		m.ajuste_cambio = ajuste
		vel = maxf(vel, Simulacao.velocidade_maxima_kmh(m.atributos_efetivos("seco"), dados.simulacao()))
	_tetos[c.id] = {"potencia": float(a["potencia"]), "peso": float(a["peso"]), "vel": vel}
	return _tetos[c.id]


## Barra da ficha: quanto do caminho entre o de fábrica e o teto do modelo o
## carro já andou, em dentes. Sem caminho (nenhuma peça muda o número), cheia.
static func _barra_teto(fabrica: float, atual: float, teto: float) -> BarraDentes:
	var n := BarraDentes.MAX_DENTES
	var faixa := teto - fabrica
	if absf(faixa) < 1e-6 or not is_finite(faixa):
		return BarraDentes.new(n, n)
	return BarraDentes.new(clampi(roundi((atual - fabrica) / faixa * n), 0, n), n)


## Pneus: os compostos comprados além do de fábrica.
func _progresso_pneus(c: Carro) -> Array:
	var fabrica: String = dados.economia().get("pneu_de_fabrica", "")
	var total: int = dados.lista("pneus").filter(func(p): return p["id"] != fabrica).size()
	var feitos: int = c.pneus.filter(func(p): return p["id"] != fabrica).size()
	return [feitos, total]


## A vitrine com a ficha por cima, como um HUD: o nome em cima, setas para
## passar pelos carros da coleção e, embaixo, potência, peso e velocidade
## máxima, cada um com a barra de quanto falta para o teto do modelo.
func _palco(c: Carro, lista: Array) -> Control:
	var palco := Control.new()
	palco.custom_minimum_size = _vitrine.custom_minimum_size
	palco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_child(palco)
	_vitrine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palco.add_child(_vitrine)
	cenario_topo(palco)
	# Cabeçalho: só o nome (e se está correndo agora).
	var tl := VBoxContainer.new()
	tl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tl.offset_left = 20
	tl.offset_right = -20
	tl.offset_top = 12
	tl.add_theme_constant_override("separation", -4)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(tl)
	Tipografia.rotulo(_hud_rotulo(c.base["nome"], 0, Color.WHITE, tl), "semibold", 48)
	if _correndo(c):
		Tipografia.rotulo(_hud_rotulo("correndo agora", 0, Color(0.86, 0.87, 0.9), tl), "medium", 26)
	if lista.size() > 1:
		var i := lista.find(c)
		for lado in [-1, 1]:
			var b := TextureButton.new()
			b.texture_normal = load(Cabecalho.PASTA + "voltar.png")
			b.ignore_texture_size = true
			b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			b.flip_h = lado > 0
			b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if lado < 0 else Control.PRESET_CENTER_RIGHT)
			b.offset_top = -SETA.y / 2.0
			b.offset_bottom = SETA.y / 2.0
			if lado < 0:
				b.offset_left = 12
				b.offset_right = 12 + SETA.x
			else:
				b.offset_left = -12 - SETA.x
				b.offset_right = -12
			var alvo: Carro = lista[posmod(i + lado, lista.size())]
			b.pressed.connect(func():
				jogador.carro_ativo = alvo.uid
				mudou.emit())
			palco.add_child(b)
	# Faixa de baixo: os resultados das peças (a Evolução embaixo mostra as
	# peças em si). Cada barra: do de fábrica até o teto do modelo.
	var a := c.atributos_efetivos("seco")
	var fab := c.copiar()
	fab.pecas = {}
	fab.ajuste_cambio = ""
	var af := fab.atributos_efetivos("seco")
	var teto := _tetos_do_modelo(c)
	var vel := Simulacao.velocidade_maxima_kmh(a, dados.simulacao())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	h.offset_top = -98
	h.offset_bottom = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(h)
	# Cada atributo: rótulo pequeno em caixa alta e, embaixo, valor grande e
	# unidade (sem ícone: o rótulo já diz o que é). O segundo item é a âncora
	# do destaque do tutorial.
	for it in [["POTÊNCIA", "POTENCIA", "%d" % a["potencia"], "cv",
				_barra_teto(af["potencia"], a["potencia"], teto["potencia"])],
			["PESO", "PESO", "%d" % a["peso"], "kg", _barra_teto(af["peso"], a["peso"], teto["peso"])],
			["VEL. MÁX", "VELOCIDADE", "—" if not is_finite(vel) else "%d" % roundi(vel), "km/h",
				_barra_teto(Simulacao.velocidade_maxima_kmh(af, dados.simulacao()), vel, teto["vel"])]]:
		var cel := VBoxContainer.new()
		cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cel.add_theme_constant_override("separation", -2)
		cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(cel)
		ancora(it[1], cel)
		var titulo := _hud_rotulo(it[0], 0, COR_SECUNDARIA, cel)
		Tipografia.rotulo(titulo, "medium", 18)
		titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var linha := HBoxContainer.new()
		linha.alignment = BoxContainer.ALIGNMENT_CENTER
		linha.add_theme_constant_override("separation", 4)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cel.add_child(linha)
		var valor := _hud_rotulo(it[2], 0, Color.WHITE, linha)
		if String(it[2]).left(1) in "0123456789+-−":
			Tipografia.numero(valor, 34)
		else:
			Tipografia.rotulo(valor, "semibold", 34)
		if it[3] != "":
			var u := _hud_rotulo(it[3], 0, COR_SECUNDARIA, linha)
			Tipografia.rotulo(u, "regular", 22)
			u.size_flags_vertical = Control.SIZE_SHRINK_END
		var margem := MarginContainer.new()
		margem.add_theme_constant_override("margin_left", 18)
		margem.add_theme_constant_override("margin_right", 18)
		margem.add_theme_constant_override("margin_top", 4)
		margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margem.add_child(it[4])
		cel.add_child(margem)
	return palco


## Evolução: cada categoria de peça que existe para o carro, com quanto já foi
## comprado (barra dentada e a conta).
func _evolucao(c: Carro) -> void:
	var v := cartao()
	Tipografia.rotulo(rotulo("EVOLUÇÃO", 0, COR_SECUNDARIA, v), "medium", 20)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 10)
	v.add_child(g)
	for cat in EVOLUCAO:
		var pr := _progresso(c, [cat])
		if pr[1] == 0:
			continue
		var cel := VBoxContainer.new()
		cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cel.add_theme_constant_override("separation", 4)
		g.add_child(cel)
		if cat == "brake":
			ancora("FREIOS", cel)
		var linha := HBoxContainer.new()
		cel.add_child(linha)
		var nome := Label.new()
		nome.text = NOMES_CATEGORIA.get(cat, cat)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.clip_text = true
		nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Tipografia.rotulo(nome, "medium", 22)
		linha.add_child(nome)
		var conta := Label.new()
		conta.text = "%d/%d" % pr
		Tipografia.numero(conta, 20)
		conta.add_theme_color_override("font_color", BarraDentes.ACESO if pr[0] > 0 else COR_SECUNDARIA)
		linha.add_child(conta)
		cel.add_child(BarraDentes.new(pr[0], pr[1]))
	var pn := _progresso_pneus(c)
	var cel_p := VBoxContainer.new()
	cel_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cel_p.add_theme_constant_override("separation", 4)
	g.add_child(cel_p)
	ancora("PNEUS", cel_p)
	var lp := HBoxContainer.new()
	cel_p.add_child(lp)
	var np := Label.new()
	np.text = "Pneus"
	np.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Tipografia.rotulo(np, "medium", 22)
	lp.add_child(np)
	var cp := Label.new()
	cp.text = "%d/%d" % pn
	Tipografia.numero(cp, 20)
	cp.add_theme_color_override("font_color", BarraDentes.ACESO if pn[0] > 0 else COR_SECUNDARIA)
	lp.add_child(cp)
	cel_p.add_child(BarraDentes.new(pn[0], pn[1]))


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
	nota("icone_comprar", "Comece por um carro barato", "Nas Lojas, cada workshop tem carros de todos os preços; os mais baratos já disputam a primeira corrida.", v)
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
	ancora("DEMANDA", b)


## Coleção: ícones (fotos em grade) ou lista (para garagens grandes); tocar
## troca o carro em destaque. Vagas e a ampliação (VagasGaragem) logo acima.
func _colecao(lista: Array, ativo: Carro) -> void:
	var cab := HBoxContainer.new()
	conteudo.add_child(cab)
	var cap: int = jogador.garagem.vagas
	var titulo := rotulo("SUA GARAGEM · %d%s CARRO%s" % [lista.size(), "/%d" % cap if cap > 0 else "",
			"" if lista.size() == 1 and cap <= 0 else "S"], 0, COR_SECUNDARIA, cab)
	Tipografia.rotulo(titulo, "medium", 22)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for modo in [["grade", false], ["lista", true]]:
		var b := Button.new()
		b.flat = true
		b.toggle_mode = true
		b.button_pressed = Preferencias.garagem_lista == modo[1]
		b.custom_minimum_size = Vector2(56, 48)
		b.tooltip_text = "Ícones" if not modo[1] else "Lista"
		var ic := IconeVetor.new(modo[0], COR_DESTAQUE if b.button_pressed else COR_SECUNDARIA)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 12
		ic.offset_right = -12
		ic.offset_top = 10
		ic.offset_bottom = -10
		b.add_child(ic)
		b.pressed.connect(func():
			Preferencias.garagem_lista = modo[1]
			Preferencias.salvar()
			mudou.emit())
		cab.add_child(b)
	_ampliacao()
	if Preferencias.garagem_lista:
		for c in lista:
			_linha_carro(c, c.uid == ativo.uid)
		return
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	conteudo.add_child(g)
	for c in lista:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 146)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", _estilo_item(c.uid == ativo.uid))
		for estado in ["hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(estado, _estilo_item(c.uid == ativo.uid))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var img := icone_carro(c.base, false, CarroBloco.cor_do_carro(c))
		img.custom_minimum_size = Vector2(0, 100)
		v.add_child(img)
		var l := Label.new()
		l.text = nome_curto(c.base["nome"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Tipografia.rotulo(l, "medium", 22)
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		v.add_child(l)
		b.pressed.connect(func():
			jogador.carro_ativo = c.uid
			mudou.emit())
		g.add_child(b)


func _estilo_item(ativo: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(8)
	sb.border_color = COR_DESTAQUE if ativo else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 12
	return sb


## Uma linha da lista: foto pequena, nome e o essencial.
func _linha_carro(c: Carro, ativo: bool) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 84)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, _estilo_item(ativo))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -12
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var img := icone_carro(c.base, false, CarroBloco.cor_do_carro(c))
	img.custom_minimum_size = Vector2(120, 76)
	h.add_child(img)
	var nome := Label.new()
	nome.text = c.base["nome"]
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nome.clip_text = true
	nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tipografia.rotulo(nome, "medium", 24)
	h.add_child(nome)
	var a := c.atributos_efetivos("seco")
	var num := Label.new()
	num.text = "%d cv · %d kg" % [roundi(a["potencia"]), roundi(a["peso"])]
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Tipografia.numero(num, 20)
	num.add_theme_color_override("font_color", COR_SECUNDARIA)
	h.add_child(num)
	b.pressed.connect(func():
		jogador.carro_ativo = c.uid
		mudou.emit())
	conteudo.add_child(b)


## Ampliar a garagem: dobra as vagas, cada vez mais caro (VagasGaragem).
func _ampliacao() -> void:
	var cap: int = jogador.garagem.vagas
	if cap <= 0:
		return
	var preco := VagasGaragem.preco(dados, jogador.ampliacoes_garagem)
	var nova := VagasGaragem.capacidade(dados, jogador.ampliacoes_garagem + 1)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	conteudo.add_child(h)
	var info := rotulo("Garagem cheia: amplie para comprar outro carro." if jogador.garagem.cheia()
			else "%d vaga%s livre%s." % [cap - jogador.garagem.lista().size(), "" if cap - jogador.garagem.lista().size() == 1 else "s",
			"" if cap - jogador.garagem.lista().size() == 1 else "s"], FONTE_PEQUENA, COR_RUIM if jogador.garagem.cheia()
			else COR_SECUNDARIA, h)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := botao("Ampliar para %d · %s G" % [nova, dinheiro(preco)], func():
		var erro := VagasGaragem.ampliar(dados, jogador)
		if erro != "":
			avisar("Não deu: %s." % erro, false)
		else:
			avisar("Garagem com %d vagas." % jogador.garagem.vagas), jogador.economia.pode_pagar(preco), false, h)
	b.custom_minimum_size = Vector2(0, 60)


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


## Garagem vazia e nenhum carro das Lojas cabe no saldo.
func _sem_saida() -> bool:
	return dados.lista("carros").all(func(c): return not jogador.economia.pode_pagar(int(c["preco"])))


func _recomecar() -> void:
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	avisar("Carreira recomeçada com %s G." % dinheiro(jogador.economia.saldo))
