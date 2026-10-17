extends Aba

## Perspectiva para quem está escolhendo o primeiro carro: faixa de posição de
## cada usado, de fábrica, em corridas simuladas da primeira prova sem licença
## (a de menor prêmio). Estimativa, não promessa. Uma vez por dia de jogo.


func _init(d: Node, j: Node) -> void:
	super(d, j, "Lojas")


## Lojas: as workshops (data/workshops.json), cada uma revende os carros de
## algumas marcas da mesma origem (decisão 42: uma loja por
## marca, agrupada nas workshops). Todos os carros da frota, novos e antigos,
## pelo preço de tabela. Sem usados nem agenda.
## Workshop aberta ("" = a grade de workshops). Fica no
## jogador (e no save): Lojas reabre na última loja vista.
var _loja: String:
	get:
		return jogador.ultima_loja
	set(v):
		jogador.ultima_loja = v
## Filtros dentro da workshop (mantidos ao voltar).
var _so_posso := false
var _ordem := "preco"  # "preco" ou "potencia"
## Cartões por vez (centenas de carros: a lista cresce sob pedido).
const POR_PAGINA := 20
var _limite := POR_PAGINA


func construir() -> void:
	_no_mapa = false
	var ws := workshops()
	var aberta: Dictionary = {}
	for w in ws:
		if w["id"] == _loja:
			aberta = w
	if aberta.is_empty():
		_loja = ""
		if ws.size() == AREAS_MAPA.size() and arte("mapa_lojas") != null:
			_mapa(ws)
		else:
			cabecalho("Lojas", "", "fundo_mercado")
			_vitrine(ws)
	else:
		_workshop(aberta)


## As workshops do jogo; sem data/workshops.json (dados de teste), uma por
## fabricante.
func workshops() -> Array:
	var ws: Array = dados.workshops()
	if ws.is_empty():
		ws = dados.lista("fabricantes").map(func(f): return {"id": f["id"], "nome": f["nome"], "logo": "",
				"fabricantes": [f["id"]]})
	return ws


func _carros_da(w: Dictionary) -> Array:
	var fabs: Array = w["fabricantes"]
	return dados.lista("carros").filter(func(c): return c["fabricante"] in fabs)


## Mapa das lojas (arte/ui/mapa_lojas.png): a estrada da costa com as seis
## concessionárias; cada uma é uma área de toque que abre a loja. Áreas em
## fração da imagem [x0, y0, x1, y1], na ordem de data/workshops.json.
## Ajuste vertical da placa do nome de cada loja (px; + desce), na ordem das áreas.
const AJUSTE_NOME_MAPA := [40.0, 0.0, 0.0, -30.0, 0.0, 0.0]
## Nomes das lojas escritos sobre elas no mapa (aba NOMES do cabeçalho). Começa
## com eles: sem os nomes, o mapa não dizia o que cada prédio vende.
var mostrar_nomes := true:
	set(v):
		mostrar_nomes = v
		# Liga e desliga as placas no lugar, sem remontar o mapa (as nuvens e as
		# gaivotas seguem onde estão).
		for p in _placas:
			if is_instance_valid(p):
				p.visible = v
var _placas: Array = []
var _no_mapa := false

const AREAS_MAPA := [
	[0.085, 0.128, 0.447, 0.258], [0.606, 0.263, 0.925, 0.362], [0.112, 0.326, 0.468, 0.458],
	[0.606, 0.487, 0.940, 0.616], [0.064, 0.610, 0.542, 0.736], [0.542, 0.807, 0.935, 0.909],
]


## O mapa está na tela (nenhuma loja aberta): o cabeçalho mostra NOMES.
func no_mapa() -> bool:
	return _no_mapa


## Faixa vertical do mapa com as lojas e os nomes delas (fração da altura da
## arte): o resto (céu e mar) pode ser recortado para o mapa caber na tela.
const MAPA_LOJAS_Y := [0.10, 0.93]


## O mapa inteiro na tela, sem rolar (pedido do usuário): na largura da tela,
## recorta céu e mar acima e abaixo das lojas; se nem assim couber, encolhe
## por igual (centrado). Nunca estica.
func _mapa(ws: Array) -> void:
	_no_mapa = true
	_placas.clear()
	var tex := arte("mapa_lojas")
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var alto_cheio := 720.0 * th / tw
	var livre := size.y - topo_livre if size.y > 0.0 else get_viewport_rect().size.y - topo_livre - 180.0
	var alto := minf(alto_cheio, maxf(livre, 400.0))
	var faixa: float = MAPA_LOJAS_Y[1] - MAPA_LOJAS_Y[0]
	var fy := clampf(alto / alto_cheio, faixa, 1.0)  # fração da altura da arte que aparece
	var centro: float = (MAPA_LOJAS_Y[0] + MAPA_LOJAS_Y[1]) / 2.0
	var y0 := clampf(centro - fy / 2.0, 0.0, 1.0 - fy)
	var largura := minf(720.0, alto / (fy * th) * tw)
	var mapa := Control.new()
	mapa.custom_minimum_size = Vector2(0, alto)
	mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(mapa)
	var t := TextureRect.new()
	if fy < 1.0:
		var recorte := AtlasTexture.new()
		recorte.atlas = tex
		recorte.region = Rect2(0, y0 * th, tw, fy * th)
		t.texture = recorte
	else:
		t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE  # o retângulo já tem a proporção do recorte
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mapa.add_child(t)
	cenario_topo(mapa)  # de borda a borda, colado no cabeçalho
	if largura < 720.0:
		# Encolhido por igual: centrado, com o fundo nas laterais.
		t.offset_left = -MARGEM_LATERAL + (720.0 - largura) / 2.0
		t.offset_right = MARGEM_LATERAL - (720.0 - largura) / 2.0
	# Ambientação, abaixo das lojas e placas: sombras das nuvens no chão, as
	# gaivotas cruzando de vez em quando e, por cima delas, as nuvens.
	var sombras := Control.new()
	sombras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.add_child(sombras)
	var gaivotas := Gaivotas.new()
	gaivotas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.add_child(gaivotas)
	var nuvens := Nuvens.new(sombras)
	nuvens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.add_child(nuvens)
	var sb_toque := StyleBoxFlat.new()
	sb_toque.bg_color = Color(1, 1, 1, 0.12)
	sb_toque.set_corner_radius_all(16)
	for i in ws.size():
		var w: Dictionary = ws[i]
		var r: Array = AREAS_MAPA[i]
		var b := Button.new()
		b.tooltip_text = String(w["nome"])
		b.focus_mode = Control.FOCUS_NONE
		for estado in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", sb_toque)
		b.anchor_left = r[0]
		b.anchor_top = (float(r[1]) - y0) / fy
		b.anchor_right = r[2]
		b.anchor_bottom = (float(r[3]) - y0) / fy
		var id := String(w["id"])
		b.pressed.connect(func():
			_loja = id
			_limite = POR_PAGINA
			set_deferred("scroll_vertical", 0)  # a loja abre do topo, não da altura do mapa
			mudou.emit())
		t.add_child(b)
		ancora("LOJA_" + id, b)
		# Placa com o nome sobre a loja, no alto da área dela (NOMES liga e desliga).
		var placa := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(COR_FUNDO, 0.82)
		sb.border_color = COR_DESTAQUE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 2
		sb.content_margin_bottom = 4
		placa.add_theme_stylebox_override("panel", sb)
		placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = String(w["nome"]).to_upper()
		Tipografia.rotulo(l, "semibold", 24)
		l.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placa.add_child(l)
		placa.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		placa.grow_horizontal = Control.GROW_DIRECTION_BOTH
		placa.offset_top += AJUSTE_NOME_MAPA[i]
		placa.offset_bottom += AJUSTE_NOME_MAPA[i]
		placa.visible = mostrar_nomes
		_placas.append(placa)
		b.add_child(placa)


## Lista das workshops (sem o mapa: dados de teste): a concessionária, o nome
## e quantos carros vende.
func _vitrine(ws: Array) -> void:
	for w in ws:
		var n := _carros_da(w).size()
		if n == 0:
			continue
		var id := String(w["id"])
		linha_workshop(w, "%d CARRO%s" % [n, "" if n == 1 else "S"], func():
			_loja = id
			_limite = POR_PAGINA
			mudou.emit())


## Volta ao mapa (aba ‹ MAPA DAS LOJAS do cabeçalho).
func voltar_ao_mapa() -> void:
	_loja = ""
	_limite = POR_PAGINA
	mudou.emit()


func _vendedor(loja: String) -> void:
	historia("LOJA:" + loja)


## Dentro da workshop: a logo grande numa placa e, embaixo, os carros.
func _topo_workshop(w: Dictionary) -> void:
	# A concessionária grande com o nome ao lado (a mesma linha do mapa/coleção).
	var n := _carros_da(w).size()
	linha_workshop(w, "%d CARRO%s À VENDA" % [n, "" if n == 1 else "S"], Callable(), -1.0, null, false)


func _workshop(w: Dictionary) -> void:
	_topo_workshop(w)
	# O vendedor da loja (cenas LOJA:<id>; cada uma só uma vez).
	_vendedor.call_deferred(String(w["id"]))
	_filtros()
	var grade := _grade()
	var tenho := {}
	for c in jogador.garagem.lista():
		tenho[c.id] = true
	var lista := _filtrar(_carros_da(w).map(func(c): return [c, int(c["preco"]), c])).map(func(x): return x[2])
	for c in lista.slice(0, _limite):
		# A cor do carro novo é escolhida na ficha (cor_escolhida).
		_bloco(grade, c, int(c["preco"]), "", [], func(): _escolher(jogador.concessionaria.comprar_carro(c, cor_escolhida), c,
				int(c["preco"])), Color(0, 0, 0, 0), true, tenho.has(c["id"]))
	_mais(lista.size())


## MOSTRAR TODOS: a lista começa com POR_PAGINA carros; o botão abre o resto.
func _mais(total: int) -> void:
	if total <= _limite:
		return
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_neutra(b, "MOSTRAR TODOS", 28, 84)
	b.pressed.connect(func():
		_limite = total
		mudou.emit())
	conteudo.add_child(b)


## Fileira de filtros: só o que posso comprar e a ordem.
func _filtros() -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 8)
	var chip := func(texto: String, ligado: bool, acao: Callable):
		var b := Button.new()
		b.text = texto
		b.toggle_mode = true
		b.button_pressed = ligado
		b.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)
		b.add_theme_font_size_override("font_size", 23)
		b.pressed.connect(func():
			acao.call()
			_limite = POR_PAGINA
			mudou.emit())
		h.add_child(b)
	chip.call("Posso comprar", _so_posso, func(): _so_posso = not _so_posso)
	chip.call("Mais baratos" if _ordem == "preco" else "Mais potentes", true,
			func(): _ordem = "potencia" if _ordem == "preco" else "preco")
	conteudo.add_child(h)



func _passa(x: Array) -> bool:
	return not _so_posso or jogador.economia.pode_pagar(x[1])


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
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	conteudo.add_child(g)
	return g


## Bloco do catálogo, no padrão da Garagem: selo JÁ COMPRADO, o carro
## grande, nome, potência e peso, e o COMPRAR no rodapé. Tocar no cartão ou
## no rodapé abre a ficha, onde a compra é confirmada.
const ALTURA_BLOCO := 420
const LARGURA_NOME_BLOCO := 290.0


func _bloco(grade: GridContainer, c: Dictionary, preco: int, marca: String, extras: Array, comprar: Callable,
		cor := Color(0, 0, 0, 0), escolher_cor := false, comprado := false) -> void:
	var pode: bool = jogador.economia.pode_pagar(preco)
	var abrir := func(): ficha_modelo(c, extras, ["Comprar por %s giros" % dinheiro(preco), comprar, pode], cor, escolher_cor)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ALTURA_BLOCO)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(8)
	sb.border_color = COR_BOM if comprado else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, sb)
	b.pressed.connect(abrir)
	grade.add_child(b)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 10
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var topo := HBoxContainer.new()
	topo.custom_minimum_size = Vector2(0, 36)
	topo.add_theme_constant_override("separation", 8)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(topo)
	if comprado:
		var vao := Control.new()
		vao.custom_minimum_size = Vector2(10, 0)
		vao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		topo.add_child(vao)
		var ok := IconeVetor.new("check", COR_BOM)
		ok.custom_minimum_size = Vector2(28, 28)
		ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
		topo.add_child(ok)
		var l := Label.new()
		l.text = "JÁ COMPRADO"
		Tipografia.rotulo(l, "semibold", 24)
		l.add_theme_color_override("font_color", COR_BOM)
		topo.add_child(l)
	var estreia: bool = jogador.garagem.lista().is_empty()
	var img := icone_carro(c, false, cor)
	img.custom_minimum_size = Vector2(0, 170 if estreia else 200)  # o selo de estreia ocupa 30
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	var nome := Label.new()
	nome.text = c["nome"] + ("  " + marca if marca != "" else "")
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.custom_minimum_size = Vector2(0, 52)
	Tipografia.rotulo(nome, "semibold", 34)
	nome.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	var f := nome.get_theme_font("font")
	var tam := 34
	while tam > 20 and f.get_string_size(nome.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > LARGURA_NOME_BLOCO:
		tam -= 2
	nome.add_theme_font_size_override("font_size", tam)
	nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nome.clip_text = true
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nome)
	# Potência e peso como no cartão de corrida: números em Racing Sans.
	var nums := HBoxContainer.new()
	nums.alignment = BoxContainer.ALIGNMENT_CENTER
	nums.custom_minimum_size = Vector2(0, 44)
	nums.add_theme_constant_override("separation", 6)
	nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nums)
	for k in 2:
		var par: Array = [["%d" % c["potencia"], "cv"], ["%d" % c["peso"], "kg"]][k]
		var n := Label.new()
		n.text = par[0]
		Tipografia.numero(n, 30)
		n.add_theme_color_override("font_color", Color(0.86, 0.87, 0.9))
		nums.add_child(n)
		var u := Label.new()
		u.text = par[1] + ("   " if k == 0 else "")
		Tipografia.rotulo(u, "regular", 22)
		u.add_theme_color_override("font_color", COR_SECUNDARIA)
		u.size_flags_vertical = Control.SIZE_SHRINK_END
		nums.add_child(u)
	if estreia:
		_estreia(c, v)
	var compra := Button.new()
	compra.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_neutra(compra, "COMPRAR · %s" % dinheiro(preco), 24, 64)
	if not pode:
		for c_fonte in ["font_color", "font_hover_color", "font_pressed_color"]:
			compra.add_theme_color_override(c_fonte, Color(0.62, 0.63, 0.68, 0.6))
	moeda(compra, 24)
	compra.pressed.connect(abrir)
	v.add_child(compra)


## Primeira compra (garagem vazia): como o carro chega na prova mais favorável
## que já dá para correr, frente ao rival mais forte dela (quem decide a vitória).
## Sem isso o jogador escolhia pelo preço e perdia as primeiras provas.
func _estreia(c: Dictionary, pai: Control) -> void:
	var carro := Carro.new(c)
	carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	var provas: Array = jogador.carreira.provas_favoraveis(carro)
	var nivel := Carreira.nivel_forca(float(provas[0]["melhor"])) if not provas.is_empty() else -1
	var l := Label.new()
	l.text = "ESTREIA: " + (Carreira.NOMES_FORCA[nivel] if nivel >= 0 else "SEM PROVA ABERTA")
	Tipografia.rotulo(l, "semibold", 20)
	l.add_theme_color_override("font_color", TONS_FORCA[maxi(nivel, 0)].lightened(0.4))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, 30)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)


## O primeiro carro já entra em uso, e a tela vai para a Garagem, que mostra o
## próximo passo.
func _escolher(uid: int, c: Dictionary, preco: int) -> void:
	if uid <= 0:
		avisar("Não deu para comprar %s: %s." % [c["nome"], "garagem cheia (amplie na Garagem)" if jogador.garagem.cheia()
				else ("saldo insuficiente" if not jogador.economia.pode_pagar(preco) else "saiu do estoque")], false)
		if not jogador.economia.pode_pagar(preco):
			historia("SEM_DINHEIRO")
		return
	Sons.tocar_ui(self, "moeda", -4.0)
	Sons.tocar_ui(self, "porta", -6.0)
	if jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
	entrega(jogador.garagem.carro(uid))
	var falou := historia("COMPRA_CARRO", {"carro": String(c["nome"])})
	if preco == int(c.get("preco", -1)):
		falou = historia("COMPRA_CARRO_NOVO") or falou
	if jogador.garagem.lista().size() == 2:
		falou = historia("GARAGEM_DOIS_CARROS") or falou
	if jogador.garagem.lista().size() >= 3 and not jogador.flags.has(EquipeJogador.FLAG_ARENA):
		if EquipeJogador.exige_piloto(jogador):
			falou = historia("GARAGEM_TRES_CARROS") or falou
		else:
			jogador.flags[EquipeJogador.FLAG_ARENA] = true
	# Comentários de contexto: só um, e só se nada mais falou nesta compra.
	var h: Historia = jogador.historia
	if h != null and not falou:
		var _f := historia("COLECAO", {"quantidade": h.colecao()}) \
				or (h.carro_caro(preco) and historia("COMPRA_CARRO_CARA", {"carro": String(c["nome"])})) \
				or (h.caixa_baixo() and historia("CAIXA_BAIXO"))
