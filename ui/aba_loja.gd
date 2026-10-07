extends Aba

## Perspectiva para quem está escolhendo o primeiro carro: faixa de posição de
## cada usado, de fábrica, em corridas simuladas da primeira prova sem licença
## (a de menor prêmio). Estimativa, não promessa. Uma vez por dia de jogo.
var _previsao := {}  # {"dia", "evento", "avaliacoes": {carro_id: Mecanico.avaliar()}}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Mercado")


## "usados" ou "novos": a seção aberta (mantida ao voltar para o Mercado).
var _secao := "usados"
## Filtros do catálogo (mantidos ao voltar).
var _so_posso := false
var _ordem := "preco"  # "preco" ou "potencia"
var _tracao := ""


func construir() -> void:
	cabecalho("Mercado", "Carros novos e usados", "fundo_mercado")
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	var novos: Array = dados.lista("carros").filter(func(c): return c.get("novo", true))
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	for s in [["usados", "Usados (%d)" % ofertas.size()], ["agenda", "Próximas ofertas"], ["novos", "Novos (%d)" % novos.size()]]:
		var b := Button.new()
		b.text = s[1]
		b.toggle_mode = true
		b.button_pressed = _secao == s[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.pressed.connect(func():
			_secao = s[0]
			mudou.emit())
		abas.add_child(b)
	conteudo.add_child(abas)
	if _secao == "agenda":
		_agenda()
		return
	_filtros()
	if _secao == "usados":
		var prev := _prever(ofertas)
		nota("icone_ofertas", "Mudam a cada corrida", "Os usados mudam conforme você corre: cada corrida é um dia."
				+ (" A previsão é a posição de fábrica (sem peças) em %s; ★ = boa chance." % prev["evento"]
				if prev.has("evento") else ""))
		if ofertas.is_empty():
			rotulo("Nenhum usado hoje.", 0, COR_SECUNDARIA)
		var grade := _grade()
		for o in _filtrar(ofertas.map(func(o): return [dados.carro(o["carro_id"]), int(o["preco"]), o])).map(func(x): return x[2]):
			var c: Dictionary = dados.carro(o["carro_id"])
			var a: Dictionary = prev.get("avaliacoes", {}).get(o["carro_id"], {})
			var estrela: bool = not a.is_empty() and a["media"] <= 1.5
			var restam: int = int(o.get("fim", jogador.dias)) - jogador.dias + 1
			var extras := [["sai em %d corrida%s" % [restam, "" if restam == 1 else "s"], COR_NEUTRA.lightened(0.3)]]
			if o["carro_id"] in jogador.desejos:
				extras.push_front(["♥ avisando", COR_DESTAQUE])
			if not a.is_empty():
				extras.push_front(["%sprevisão %s" % ["★ " if estrela else "", Mecanico.texto_faixa(a["faixa"])],
						COR_BOM if estrela else COR_NEUTRA.lightened(0.3)])
			_bloco(grade, c, int(o["preco"]), "★" if estrela else "", extras,
					func(): _escolher(jogador.concessionaria.comprar_usado(o, c, jogador.usados_vendidos), c, int(o["preco"])))
	else:
		nota("icone_ok", "Sempre disponíveis", "Os novos estão sempre à venda. Modelos antigos só aparecem nos usados.")
		var grade := _grade()
		for c in _filtrar(novos.map(func(c): return [c, int(c["preco"]), c])).map(func(x): return x[2]):
			_bloco(grade, c, int(c["preco"]), "", [], func(): _escolher(jogador.concessionaria.comprar_carro(c), c, int(c["preco"])))


## Corridas à frente que a agenda mostra (GT2: períodos de 10 dias; três deles).
const HORIZONTE_AGENDA := 30


## Agenda dos usados: os acompanhados (quando aparecem) e as próximas ofertas.
## O estoque depende só do número de corridas, então a agenda é exata.
func _agenda() -> void:
	nota("icone_ofertas", "Cada corrida é um dia", "As ofertas são exatas: o estoque só muda com as corridas.")
	var v := cartao(COR_DESTAQUE)
	titulo_secao("AVISAR QUANDO APARECER", "Abra a ficha de um modelo e toque em \"Avisar quando aparecer usado\".",
			v, COR_DESTAQUE)
	if jogador.desejos.is_empty():
		nota("icone_avisar", "Nenhum modelo marcado", "", v)
	for cid in jogador.desejos:
		var c: Dictionary = dados.carro(cid)
		var p := Usados.proxima(c, jogador.dias, jogador.usados_vendidos)
		var quando := "não volta aos usados" + (" (novo: %s Cr)" % dinheiro(int(c["preco"])) if c.get("novo", true) else "")
		if not p.is_empty() and p["inicio"] <= jogador.dias:
			quando = "à venda agora por %s Cr · sai em %d corrida%s" % [dinheiro(p["preco"]), p["fim"] - jogador.dias + 1,
					"" if p["fim"] - jogador.dias + 1 == 1 else "s"]
		elif not p.is_empty():
			quando = "em %d corrida%s, por %s Cr" % [p["inicio"] - jogador.dias, "" if p["inicio"] - jogador.dias == 1 else "s",
					dinheiro(p["preco"])]
		var h := fileira(v)
		var img := icone_carro(c)
		img.custom_minimum_size = Vector2(110, 62)
		h.add_child(img)
		var l := rotulo("%s\n%s" % [c["nome"], quando], FONTE_PEQUENA + 1, Color.WHITE, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao_texto("Parar", func():
			jogador.desejos.erase(cid)
			mudou.emit(), h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lista := Usados.agenda(dados.lista("carros"), jogador.dias, HORIZONTE_AGENDA)
	rotulo("PRÓXIMAS OFERTAS · %d corridas à frente" % HORIZONTE_AGENDA, FONTE_PEQUENA, COR_SECUNDARIA)
	if lista.is_empty():
		rotulo("Nenhuma oferta nova nesse intervalo.", FONTE_PEQUENA + 2, COR_SECUNDARIA)
	var inicio := -1
	var vc: VBoxContainer = null
	for o in lista:
		if o["inicio"] != inicio:
			inicio = o["inicio"]
			vc = cartao()
			var n: int = inicio - jogador.dias
			rotulo("Em %d corrida%s" % [n, "" if n == 1 else "s"], 28, Color.WHITE, vc)
		var c: Dictionary = dados.carro(o["carro_id"])
		var h := fileira(vc)
		var l := rotulo("%s%s · %d cv · %s" % ["♥ " if c["id"] in jogador.desejos else "", c["nome"], c["potencia"], c["tracao"]],
				FONTE_PEQUENA + 1, COR_DESTAQUE if c["id"] in jogador.desejos else Color.WHITE, h)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var b := botao_texto("%s Cr" % dinheiro(o["preco"]), func(): ficha_modelo(c, [["à venda em %d corridas" % (o["inicio"] - jogador.dias),
				COR_NEUTRA.lightened(0.3)]]), h)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Fileira de filtros: só o que posso comprar, ordem e tração.
func _filtros() -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 8)
	var chip := func(texto: String, ligado: bool, acao: Callable):
		var b := Button.new()
		b.text = texto
		b.toggle_mode = true
		b.button_pressed = ligado
		b.custom_minimum_size = Vector2(0, 54)
		b.add_theme_font_size_override("font_size", 23)
		b.pressed.connect(func():
			acao.call()
			mudou.emit())
		h.add_child(b)
	chip.call("Posso comprar", _so_posso, func(): _so_posso = not _so_posso)
	chip.call("Mais baratos" if _ordem == "preco" else "Mais potentes", true,
			func(): _ordem = "potencia" if _ordem == "preco" else "preco")
	for t in ["", "FF", "FR", "MR", "4WD"]:
		chip.call("Todas" if t == "" else t, _tracao == t, func(): _tracao = t)
	conteudo.add_child(h)


func _passa(x: Array) -> bool:
	return (not _so_posso or jogador.economia.pode_pagar(x[1])) and (_tracao == "" or x[0]["tracao"] == _tracao)


## Aplica os filtros a [[carro, preço, item], ...].
func _filtrar(itens: Array) -> Array:
	var r := itens.filter(func(x): return _passa(x))
	if _ordem == "preco":
		r.sort_custom(func(a, b): return a[1] < b[1])
	else:
		r.sort_custom(func(a, b): return a[0]["potencia"] > b[0]["potencia"])
	if r.is_empty():
		rotulo("Nenhum carro com esses filtros.", FONTE_PEQUENA + 2, COR_SECUNDARIA)
	return r


func _grade() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	conteudo.add_child(g)
	return g


## Bloco do catálogo: foto, nome, preço e o essencial (potência e tração).
## Tocar abre a ficha, onde está o botão de compra.
func _bloco(grade: GridContainer, c: Dictionary, preco: int, marca: String, extras: Array, comprar: Callable) -> void:
	var pode: bool = jogador.economia.pode_pagar(preco)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(14)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 6
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var img := icone_carro(c)
	img.custom_minimum_size = Vector2(0, 120)
	v.add_child(img)
	for t in [[c["nome"] + ("  " + marca if marca != "" else ""), 27, Color.WHITE],
			["%d cv · %s" % [c["potencia"], c["tracao"]], 23, COR_SECUNDARIA],
			["%s Cr" % dinheiro(preco), 32, Color.WHITE if pode else Color(0.72, 0.73, 0.78)]]:
		var l := Label.new()
		l.text = t[0]
		l.add_theme_font_size_override("font_size", t[1])
		l.add_theme_color_override("font_color", t[2])
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		v.add_child(l)
	var falta := "" if pode else "Faltam %s Cr" % dinheiro(preco - jogador.economia.saldo)
	b.pressed.connect(func(): ficha_modelo(c, extras + [["revenda %s Cr" % dinheiro(revenda(c)), COR_NEUTRA.lightened(0.3)]],
			["Comprar · %s Cr" % dinheiro(preco), comprar, true] if pode else [falta, comprar, false]))
	grade.add_child(b)


func _prever(ofertas: Array) -> Dictionary:
	if jogador.carreira == null:
		return {}
	if _previsao.get("dia", -1) == jogador.dias:
		return _previsao
	var sem_licenca: Array = dados.lista("eventos").filter(func(e): return not e["restricoes"].has("licenca") and not e["premios"].is_empty())
	if sem_licenca.is_empty():
		return {}
	sem_licenca.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0])
	var ev: Dictionary = sem_licenca[0]
	var avaliacoes := {}
	for o in ofertas:
		var c := Carro.new(dados.carro(o["carro_id"]))
		c.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		avaliacoes[o["carro_id"]] = Mecanico.avaliar(jogador.carreira, ev["id"], -1, c)
	_previsao = {"dia": jogador.dias, "evento": ev["nome"], "avaliacoes": avaliacoes}
	return _previsao


## O primeiro carro já entra em uso, e a tela vai para a Garagem, que mostra o
## próximo passo.
func _escolher(uid: int, c: Dictionary, preco: int) -> void:
	if uid <= 0:
		avisar("Não deu para comprar %s: %s." % [c["nome"], "saldo insuficiente" if not jogador.economia.pode_pagar(preco)
				else "saiu do estoque"], false)
		return
	if jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
	entrega(jogador.garagem.carro(uid))
