extends Aba

## Perspectiva para quem está escolhendo o primeiro carro: faixa de posição de
## cada usado, de fábrica, em corridas simuladas da primeira prova sem licença
## (a de menor prêmio). Estimativa, não promessa. Uma vez por dia de jogo.


func _init(d: Node, j: Node) -> void:
	super(d, j, "Mercado")


## Lojas como no GT2: concessionárias de novos por fabricante, separadas por
## região; lotes de usados por fabricante; agenda das próximas ofertas.
## "usados", "novos" ou "agenda": a seção aberta (mantida ao voltar).
var _secao := "usados"
## Região das concessionárias e loja aberta (id do fabricante; "" = a vitrine
## de lojas). "todos" nos usados = todos os lotes juntos.
var _regiao := "jp"
var _loja := ""
## Filtros dentro da loja (mantidos ao voltar).
var _so_posso := false
var _ordem := "preco"  # "preco" ou "potencia"
var _tracao := ""
## Cartões por vez (centenas de carros: a lista cresce sob pedido).
const POR_PAGINA := 20
var _limite := POR_PAGINA
const REGIOES := [["jp", "Japão"], ["us", "Estados Unidos"], ["eu", "Europa"]]


static func regiao_de(fabricante: Dictionary) -> String:
	var e: String = fabricante.get("escola", "")
	return e if e in ["jp", "us"] else "eu"


func construir() -> void:
	cabecalho("Mercado", "Concessionárias e usados", "fundo_mercado")
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	var novos: Array = dados.lista("carros").filter(func(c): return c.get("novo", true))
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	for s in [["usados", "Usados"], ["novos", "Concessionárias"], ["agenda", "Próximas ofertas"]]:
		var b := Button.new()
		b.text = s[1]
		b.toggle_mode = true
		b.button_pressed = _secao == s[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(func():
			_secao = s[0]
			_loja = ""
			_limite = POR_PAGINA
			mudou.emit())
		abas.add_child(b)
	conteudo.add_child(abas)
	if _secao == "agenda":
		_agenda()
	elif _secao == "usados":
		if _loja == "":
			_vitrine_usados(ofertas)
		else:
			_lote(ofertas)
	elif _loja == "":
		_vitrine_concessionarias(novos)
	else:
		_concessionaria(novos)


## Lotes de usados do dia, um por fabricante (como os do GT2), e "todos".
func _vitrine_usados(ofertas: Array) -> void:
	nota("icone_ofertas", "Mudam a cada corrida", "Os usados mudam conforme você corre: cada corrida é um dia. "
			+ "Cada fabricante tem o seu lote.")
	if ofertas.is_empty():
		rotulo("Nenhum usado hoje.", 0, COR_SECUNDARIA)
		return
	var por_fab := {}
	for o in ofertas:
		por_fab.get_or_add(dados.carro(o["carro_id"])["fabricante"], []).append(int(o["preco"]))
	var grade := _grade()
	_cartao_loja(grade, "todos", "Todos os lotes", "", ofertas.size(), ofertas.map(func(o): return int(o["preco"])).min())
	for f in _fabricantes_ordenados(por_fab.keys()):
		_cartao_loja(grade, f["id"], f["nome"], f.get("pais", ""), por_fab[f["id"]].size(), por_fab[f["id"]].min())


## Concessionárias de novos da região escolhida.
func _vitrine_concessionarias(novos: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for r in REGIOES:
		var b := Button.new()
		b.text = r[1]
		b.toggle_mode = true
		b.button_pressed = _regiao == r[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_size_override("font_size", 23)
		b.pressed.connect(func():
			_regiao = r[0]
			mudou.emit())
		h.add_child(b)
	conteudo.add_child(h)
	nota("icone_ok", "Sempre à venda", "Cada fabricante tem a sua concessionária, com os modelos novos dele. "
			+ "Modelos antigos só aparecem nos usados.")
	var por_fab := {}
	for c in novos:
		por_fab.get_or_add(c["fabricante"], []).append(int(c["preco"]))
	var fabs := _fabricantes_ordenados(por_fab.keys()).filter(func(f): return regiao_de(f) == _regiao)
	var grade := _grade()
	for f in fabs:
		_cartao_loja(grade, f["id"], f["nome"], f.get("pais", ""), por_fab[f["id"]].size(), por_fab[f["id"]].min())


func _fabricantes_ordenados(ids: Array) -> Array:
	var fabs: Array = dados.lista("fabricantes").filter(func(f): return f["id"] in ids)
	fabs.sort_custom(func(a, b): return a["nome"] < b["nome"])
	return fabs


## Cartão de uma loja: emblema, nome, país e quantos carros a partir de quanto.
func _cartao_loja(grade: GridContainer, id: String, nome: String, pais: String, n: int, desde: int) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(14)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_right = -12
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_theme_constant_override("separation", 10)
	v.add_child(topo)
	topo.add_child(emblema_fabricante(id, nome, 52))
	var t := VBoxContainer.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_theme_constant_override("separation", -4)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(t)
	for linha in [[nome, 27, Color.WHITE], [pais, 21, COR_SECUNDARIA]]:
		if linha[0] == "":
			continue
		var l := Label.new()
		l.text = linha[0]
		l.add_theme_font_size_override("font_size", linha[1])
		l.add_theme_color_override("font_color", linha[2])
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		t.add_child(l)
	var info := Label.new()
	info.text = "%d carro%s · desde %s Cr" % [n, "" if n == 1 else "s", dinheiro(desde)]
	info.add_theme_font_size_override("font_size", 21)
	info.add_theme_color_override("font_color", COR_SECUNDARIA)
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.clip_text = true
	v.add_child(info)
	b.pressed.connect(func():
		_loja = id
		_limite = POR_PAGINA
		mudou.emit())
	grade.add_child(b)


## Emblema provisório do fabricante: círculo na cor dele com a inicial (até a
## arte "emblema_fab_<id>" existir).
func emblema_fabricante(id: String, nome: String, tamanho: int) -> Control:
	var arte_emblema := arte("emblema_fab_" + id)
	if arte_emblema != null:
		var t := TextureRect.new()
		t.texture = arte_emblema
		t.custom_minimum_size = Vector2(tamanho, tamanho)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(tamanho, tamanho)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.from_hsv(float(posmod(hash(id), 360)) / 360.0, 0.35, 0.42) if id != "todos" else COR_NEUTRA
	sb.set_corner_radius_all(tamanho / 2)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "∗" if id == "todos" else nome.left(1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(tamanho * 0.55))
	p.add_child(l)
	return p


## Cabeçalho dentro de uma loja: voltar à vitrine, emblema e nome.
func _topo_loja(nome: String, sub: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	conteudo.add_child(h)
	var voltar := botao_texto("‹ Lojas", func():
		_loja = ""
		_limite = POR_PAGINA
		mudou.emit(), h)
	voltar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(emblema_fabricante(_loja, nome, 44))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var l := rotulo(nome, 30, Color.WHITE, v)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	if sub != "":
		rotulo(sub, FONTE_PEQUENA, COR_SECUNDARIA, v).autowrap_mode = TextServer.AUTOWRAP_OFF


## Um lote de usados (ou todos), com filtros. Sem recomendação, como no GT2.
func _lote(ofertas: Array) -> void:
	var f: Dictionary = dados.item("fabricantes", _loja) if _loja != "todos" else {}
	_topo_loja(f.get("nome", "Todos os lotes"), "Usados · " + f.get("pais", "todos os fabricantes"))
	if _loja != "todos":
		ofertas = ofertas.filter(func(o): return dados.carro(o["carro_id"])["fabricante"] == _loja)
	_filtros()
	var grade := _grade()
	var lista := _filtrar(ofertas.map(func(o): return [dados.carro(o["carro_id"]), int(o["preco"]), o])).map(func(x): return x[2])
	for o in lista.slice(0, _limite):
		var c: Dictionary = dados.carro(o["carro_id"])
		var restam: int = int(o.get("fim", jogador.dias)) - jogador.dias + 1
		var extras := [["sai em %d corrida%s" % [restam, "" if restam == 1 else "s"], COR_NEUTRA.lightened(0.3)]]
		if o["carro_id"] in jogador.desejos:
			extras.push_front(["♥ avisando", COR_DESTAQUE])
		# Usado: vem numa das cores do modelo, fixa pela oferta.
		var cor_usado := Cores.sortear(String(c["id"]), String(o["chave"]))
		_bloco(grade, c, int(o["preco"]), "", extras,
				func(): _escolher(jogador.concessionaria.comprar_usado(o, c, jogador.usados_vendidos, cor_usado.to_html(false)), c,
						int(o["preco"])), cor_usado)
	_mais(lista.size())


## Concessionária de um fabricante: os novos dele; as versões de corrida por
## último.
func _concessionaria(novos: Array) -> void:
	var f: Dictionary = dados.item("fabricantes", _loja)
	_topo_loja(f.get("nome", _loja), "Concessionária · " + f.get("pais", ""))
	_filtros()
	var grade := _grade()
	var lista := _filtrar(novos.filter(func(c): return c["fabricante"] == _loja).map(func(c): return [c, int(c["preco"]), c])) \
			.map(func(x): return x[2])
	for c in lista.slice(0, _limite):
		# Carro novo: a cor é escolhida na ficha (cor_escolhida), como no GT2.
		_bloco(grade, c, int(c["preco"]), "", [], func(): _escolher(jogador.concessionaria.comprar_carro(c, cor_escolhida), c,
				int(c["preco"])), Color(0, 0, 0, 0), true)
	_mais(lista.size())


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


## "Mostrar mais": a lista cresce POR_PAGINA de cada vez.
func _mais(total: int) -> void:
	if total <= _limite:
		return
	botao_texto("Mostrar mais (%d de %d)" % [_limite, total], func():
		_limite += POR_PAGINA
		mudou.emit())


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
			_limite = POR_PAGINA
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
func _bloco(grade: GridContainer, c: Dictionary, preco: int, marca: String, extras: Array, comprar: Callable,
		cor := Color(0, 0, 0, 0), escolher_cor := false) -> void:
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
	var img := icone_carro(c, false, cor)
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
			["Comprar · %s Cr" % dinheiro(preco), comprar, true] if pode else [falta, comprar, false], cor, escolher_cor))
	grade.add_child(b)


## O primeiro carro já entra em uso, e a tela vai para a Garagem, que mostra o
## próximo passo.
func _escolher(uid: int, c: Dictionary, preco: int) -> void:
	if uid <= 0:
		avisar("Não deu para comprar %s: %s." % [c["nome"], "saldo insuficiente" if not jogador.economia.pode_pagar(preco)
				else "saiu do estoque"], false)
		if not jogador.economia.pode_pagar(preco):
			historia("SEM_DINHEIRO")
		return
	if jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
	entrega(jogador.garagem.carro(uid))
	historia("COMPRA_CARRO")
	if preco == int(c.get("preco", -1)):
		historia("COMPRA_CARRO_NOVO")
	if jogador.garagem.lista().size() == 2:
		historia("GARAGEM_DOIS_CARROS")
