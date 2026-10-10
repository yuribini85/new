extends Aba
## Oficina (antes "Garagem"): o carro selecionado em destaque (vitrine com o
## sprite isométrico) com a ficha por cima, como HUD, e a Evolução (tocar numa
## categoria abre a compra), sem rolagem, sobre o cenário que passa por trás de
## tudo. Os carros, as vagas e a venda ficam na janela GARAGEM, aberta pela aba
## pendurada no cabeçalho; correr fica na barra de baixo.

var _vitrine: VitrineCarro

## Apresentação da Oficina (não balanceamento).
## Escurecimento do cenário abaixo do palco (leitura da Evolução).
const VEU_FUNDO := 0.55


## Cenário pintado atrás da tela inteira (palco, missão e Evolução).
var _fundo: Texture2D


func _init(d: Node, j: Node) -> void:
	super(d, j, "Oficina")
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER  # tudo cabe: sem rolagem
	_vitrine = VitrineCarro.new(ALTURA_PALCO)
	_fundo = Aba.arte("fundo_oficina")
	if _fundo != null:
		_vitrine.fundo_transparente()
	else:
		_vitrine.ambiente_garagem()
	resized.connect(queue_redraw)


## O cenário (retrato) cobre a tela com escala uniforme (recorta, nunca
## estica), colado no topo: o chão iluminado fica atrás do carro.
func _draw() -> void:
	if _fundo == null:
		return
	var tam := _fundo.get_size()
	var escala := maxf(size.x / tam.x, size.y / tam.y)
	draw_texture_rect(_fundo, Rect2(Vector2((size.x - tam.x * escala) * 0.5, 0.0), tam * escala), false)
	# Véu: a Evolução lê por cima do cenário.
	var veu_y := _vitrine.get_global_rect().end.y - get_global_rect().position.y if _vitrine.is_inside_tree() else 0.0
	draw_rect(Rect2(0, veu_y, size.x, size.y - veu_y), Color(COR_FUNDO, VEU_FUNDO))


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
	# O palco é o cenário do topo (colado no cabeçalho); sem a faixa da missão,
	# o palco cresce e o carro respira.
	# Melhorar é tocar na Evolução (abre a compra da categoria); correr fica na
	# barra de baixo; os carros e a venda, na janela GARAGEM do cabeçalho.
	_evolucao(c)
	queue_redraw.call_deferred()


## Todas as categorias compráveis, na ordem da seção Evolução.
const EVOLUCAO := ["aspiracao", "muffler", "computer", "intercooler", "portpolish", "enginebalance", "displacement",
		"lightweight", "corrida", "brake", "cambio"]
const NOMES_CATEGORIA := PecasTexto.NOMES_CATEGORIA
## Nome do carro no palco (fonte) e altura da diagonal ocre na frente dele;
## a linha fica na altura das abas penduradas, à esquerda delas.
const TAMANHO_NOME := 34
const TAMANHO_NOME_MIN := 24
const ALTURA_NOME := 40
const TOPO_NOME := 4
const RESERVA_ABAS := 456
const OPACIDADE_SETAS := 0.5
## Quanto o carro em sprite sobe no palco (px).
const SUBIR_SPRITE := 60.0
## Altura do palco (carro e ficha): ocupa o espaço que sobra até a Evolução.
const ALTURA_PALCO := 560.0
## Cartões da ficha (potência, peso, velocidade máxima): altura, ícone, dentes
## da barra e a cor do ícone com a barra vazia (cheia: COR_DESTAQUE).
const ALTURA_FICHA := 128
const TAMANHO_ICONE_FICHA := 88
const DENTES_FICHA := 6
const COR_ICONE_FICHA := Color("ece6da")
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


## Quanto do caminho entre o de fábrica e o teto do modelo o carro já andou
## (0 a 1). Sem caminho (nenhuma peça muda o número), 1.
static func _fracao_teto(fabrica: float, atual: float, teto: float) -> float:
	var faixa := teto - fabrica
	if absf(faixa) < 1e-6 or not is_finite(faixa):
		return 1.0
	return clampf((atual - fabrica) / faixa, 0.0, 1.0)


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
	# A arte dos carros é desenhada num ângulo mais alto que o carro 3D: o
	# sprite sobe para assentar no chão iluminado do cenário.
	var subir := SUBIR_SPRITE if ArteCarro.textura(c.id, "iso") != null else 0.0
	_vitrine.offset_top = -subir
	_vitrine.offset_bottom = -subir
	# Cabeçalho: só o nome (e se está correndo agora).
	var tl := VBoxContainer.new()
	tl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tl.offset_left = 20
	tl.offset_right = -RESERVA_ABAS  # à esquerda das abas penduradas (GARAGEM, ACELERAR)
	tl.offset_top = TOPO_NOME  # na altura delas
	tl.add_theme_constant_override("separation", -4)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(tl)
	# Nome com a diagonal ocre do cabeçalho na frente (a mesma do painel de giros).
	var linha_nome := HBoxContainer.new()
	linha_nome.add_theme_constant_override("separation", 10)
	linha_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.add_child(linha_nome)
	var diag := TextureRect.new()
	diag.texture = load(Cabecalho.PASTA + "diagonal.png")
	diag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diag.custom_minimum_size = Vector2(ALTURA_NOME * 88.0 / 119.0, ALTURA_NOME)
	diag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha_nome.add_child(diag)
	var nome_carro := _hud_rotulo(c.base["nome"], 0, Color.WHITE, linha_nome)
	# Nome longo: a fonte diminui até caber ao lado das abas (depois, "…").
	var livre := 720.0 - 2.0 * MARGEM_LATERAL - 20.0 - RESERVA_ABAS - ALTURA_NOME * 88.0 / 119.0 - 10.0
	var tam := TAMANHO_NOME
	Tipografia.rotulo(nome_carro, "semibold", tam)
	# Mede com a fonte do próprio rótulo (com o espaçamento entre letras).
	var fonte_nome := nome_carro.get_theme_font("font")
	while tam > TAMANHO_NOME_MIN and fonte_nome.get_string_size(c.base["nome"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > livre:
		tam -= 2
	nome_carro.add_theme_font_size_override("font_size", tam)
	nome_carro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome_carro.clip_text = true
	nome_carro.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nome_carro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
			b.modulate.a = OPACIDADE_SETAS
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
	h.offset_left = 12
	h.offset_right = -12
	h.offset_top = -12 - ALTURA_FICHA
	h.offset_bottom = -12
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(h)
	# Cada atributo num cartão: ícone, valor grande e unidade, e a barra embaixo.
	# O ícone vai do branco ao dourado conforme a barra enche.
	for it in [["potencia", "POTENCIA", "%d" % a["potencia"], "cv",
				_fracao_teto(af["potencia"], a["potencia"], teto["potencia"])],
			["peso", "PESO", "%d" % a["peso"], "kg", _fracao_teto(af["peso"], a["peso"], teto["peso"])],
			["velocidade", "VELOCIDADE", "—" if not is_finite(vel) else "%d" % roundi(vel), "km/h",
				_fracao_teto(Simulacao.velocidade_maxima_kmh(af, dados.simulacao()), vel, teto["vel"])]]:
		var cartao_ficha := PanelContainer.new()
		cartao_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cartao_ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var e := StyleBoxFlat.new()
		e.bg_color = Color(COR_FUNDO, 0.82)
		e.border_color = Color(1, 1, 1, 0.1)
		e.set_border_width_all(1)
		e.set_corner_radius_all(8)
		e.content_margin_left = 12
		e.content_margin_right = 12
		e.content_margin_top = 10
		e.content_margin_bottom = 12
		cartao_ficha.add_theme_stylebox_override("panel", e)
		h.add_child(cartao_ficha)
		ancora(it[1], cartao_ficha)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cartao_ficha.add_child(v)
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 10)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(linha)
		var icone := TextureRect.new()
		icone.texture = load("res://arte/ui/garagem/%s.png" % it[0])
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.custom_minimum_size = Vector2(TAMANHO_ICONE_FICHA, TAMANHO_ICONE_FICHA)
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icone.modulate = COR_ICONE_FICHA.lerp(COR_DESTAQUE, it[4])
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(icone)
		var num := VBoxContainer.new()
		num.add_theme_constant_override("separation", -6)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(num)
		var valor := _hud_rotulo(it[2], 0, Color.WHITE, num)
		Tipografia.numero(valor, 44)
		var u := _hud_rotulo(it[3], 0, COR_SECUNDARIA, num)
		Tipografia.rotulo(u, "regular", 40)
		var dentes := DENTES_FICHA
		v.add_child(BarraDentes.new(roundi(it[4] * dentes), dentes, 7.0))
	return palco


## Evolução: cada categoria de peça que existe para o carro, com quanto já foi
## comprado (barra dentada e a conta).
func _evolucao(c: Carro) -> void:
	# Sem título nem caixa: as categorias direto sobre o cenário.
	var v := MarginContainer.new()
	v.add_theme_constant_override("margin_left", 16)
	v.add_theme_constant_override("margin_right", 16)
	v.add_theme_constant_override("margin_top", 8)
	conteudo.add_child(v)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	var itens := []
	for cat in EVOLUCAO:
		var pr := _progresso(c, [cat])
		if pr[1] > 0:
			itens.append([cat, NOMES_CATEGORIA.get(cat, cat), pr])
	itens.append(["pneus", "Pneus", _progresso_pneus(c)])
	var demanda := String(dados.historia().get("adrian", {}).get("peca_demanda", ""))
	var cat_demanda := String(dados.peca(demanda).get("categoria", "")) if dados.existe("pecas", demanda) else ""
	for it in itens:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxEmpty.new()
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		for estado in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(estado, sb)
		g.add_child(b)
		# A demanda do Marcus (prólogo) aponta para a categoria da peça pedida.
		if it[0] == cat_demanda:
			ancora("DEMANDA", b)
		if it[0] == "brake":
			ancora("FREIOS", b)
		elif it[0] == "pneus":
			ancora("PNEUS", b)
		var cel := VBoxContainer.new()
		cel.add_theme_constant_override("separation", 4)
		cel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cel)
		var linha := HBoxContainer.new()
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cel.add_child(linha)
		var nome := Label.new()
		nome.text = it[1]
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nome.clip_text = true
		nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Tipografia.rotulo(nome, "medium", 29)
		linha.add_child(nome)
		var conta := Label.new()
		conta.text = "%d/%d" % it[2]
		Tipografia.numero(conta, 26)
		conta.add_theme_color_override("font_color", BarraDentes.ACESO if it[2][0] > 0 else COR_SECUNDARIA)
		linha.add_child(conta)
		cel.add_child(BarraDentes.new(it[2][0], it[2][1]))
		# O botão não mede os filhos: a altura vem do conteúdo.
		var ajustar := func(): b.custom_minimum_size.y = cel.get_combined_minimum_size().y + 12.0
		cel.minimum_size_changed.connect(ajustar)
		ajustar.call()
		cel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cel.offset_top = 6
		cel.offset_bottom = -6
		b.pressed.connect(_abrir_evolucao.bind(c, it[0]))
	if _abrir_categoria != "":
		var cat := _abrir_categoria
		_abrir_categoria = ""
		_abrir_evolucao(c, cat)


## Categoria a abrir na próxima construção (destaque do tutorial).
var _abrir_categoria := ""


## Destaque dos freios (tutorial): a janela de compra dos freios aberta.
func preparar_destaque(nome: String) -> void:
	if nome == "BRAKES":
		_abrir_categoria = "brake"


## Janela de compra de uma categoria da Evolução: cada estágio com o ganho
## sobre a montagem atual e a ação (comprar, usar, remover). Substitui a Oficina.
func _abrir_evolucao(c: Carro, cat: String) -> void:
	var titulo := ("Pneus" if cat == "pneus" else String(NOMES_CATEGORIA.get(cat, cat))).to_upper()
	var acao := _acao_evolucao(c, cat)
	painel_estilo.emit(titulo, func(v):
		if cat == "pneus":
			_janela_pneus(c, v)
		else:
			_janela_pecas(c, cat, v), [[acao[0], acao[1], "giros" if acao[2] else ""]],
			{"titulo_centro": true, "titulo_max": 80, "principal": true, "fora_fecha": true, "habilitado": acao[3]})
	historia("EVOLUCAO")


## Refaz a janela depois de uma compra (a tela inteira foi reconstruída).
func _reabrir(c: Carro, cat: String) -> void:
	var atual: Carro = jogador.garagem.carro(c.uid)
	if atual != null:
		(func(): _abrir_evolucao(atual, cat)).call_deferred()


## Item escolhido na janela de cada categoria ("" = o padrão: o próximo
## estágio depois do instalado, ou o instalado se for o último).
var _escolha := {}


func _itens(c: Carro, cat: String) -> Array:
	if cat == "pneus":
		return dados.lista("pneus")
	var pecas: Array = dados.lista("pecas").filter(func(p): return p["categoria"] == cat and c.motivo_recusa(p).is_empty())
	pecas.sort_custom(func(a, b): return a["preco"] < b["preco"])
	return pecas


func _escolhido(c: Carro, cat: String) -> Dictionary:
	var itens := _itens(c, cat)
	if itens.is_empty():
		return {}
	for it in itens:
		if it["id"] == _escolha.get(cat, ""):
			return it
	if cat == "pneus":
		for pn in itens:
			if not c.pneus.any(func(x): return x["id"] == pn["id"]):
				return pn
		return itens[-1]
	var em_uso := String(c.pecas.get(cat, {}).get("id", ""))
	var i := itens.map(func(p): return p["id"]).find(em_uso)
	return itens[mini(i + 1, itens.size() - 1)]


## A ação da janela para o item escolhido: [texto, Callable, com moeda, habilitada].
func _acao_evolucao(c: Carro, cat: String) -> Array:
	var it := _escolhido(c, cat)
	if it.is_empty():
		return ["FECHAR", func(): pass, false, true]
	var preco := int(it["preco"])
	if cat == "pneus":
		var tem: bool = c.pneus.any(func(x): return x["id"] == it["id"])
		if tem:
			return ["JÁ É SEU", func(): pass, false, false]
		return ["INSTALAR · %s" % dinheiro(preco), func():
			_comprar_pneu(c, it)
			_reabrir(c, cat), true, jogador.economia.pode_pagar(preco)]
	var instalada: bool = c.pecas.get(cat, {}).get("id") == it["id"]
	var antes := c.atributos_efetivos("seco")
	if instalada:
		return ["REMOVER", func():
			_remover(c, it)
			_reabrir(c, cat), false, true]
	if it["id"] in c.pecas_possuidas:
		return ["INSTALAR", func():
			_comprar_peca(c, it, antes)
			_reabrir(c, cat), false, true]
	return ["INSTALAR · %s" % dinheiro(preco), func():
		_comprar_peca(c, it, antes)
		_reabrir(c, cat), true, jogador.economia.pode_pagar(preco)]


## Um item da janela: o nome e o ganho em caixa alta, centrados; o escolhido
## com borda ocre, o instalado em verde. Tocar escolhe (a ação fica embaixo).
func _item_evolucao(v: VBoxContainer, c: Carro, cat: String, id: String, texto: String, estado: String,
		escolhido: bool) -> Button:
	var b := Button.new()
	b.text = texto.to_upper()
	b.custom_minimum_size = Vector2(0, 76)
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.rotulo(b, "semibold", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO.lightened(0.05)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = COR_DESTAQUE if escolhido else (COR_BOM if estado == "uso" else Color(1, 1, 1, 0.08))
	for e in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(e, sb)
	var cor := COR_DESTAQUE if escolhido else (COR_BOM if estado == "uso" else Color(0.93, 0.91, 0.87))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, cor)
	b.pressed.connect(func():
		_escolha[cat] = id
		_reabrir(c, cat))
	v.add_child(b)
	return b


## O que a categoria faz na corrida, breve, centrado.
func _descritivo(v: VBoxContainer, texto: String) -> void:
	var l := rotulo(texto.left(1).to_upper() + texto.substr(1) + ".", FONTE_PEQUENA + 4, COR_SECUNDARIA, v)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## PROIBIÇÕES DE USO do item escolhido: as provas em que o carro deixa de
## poder correr com ele.
func _proibicoes(v: VBoxContainer, perde: Array) -> void:
	var q := cartao(COR_RUIM if not perde.is_empty() else Color.TRANSPARENT, v)
	var t := rotulo("PROIBIÇÕES DE USO", 0, COR_RUIM if not perde.is_empty() else COR_SECUNDARIA, q)
	Tipografia.rotulo(t, "semibold", 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l := rotulo("Nenhuma" if perde.is_empty() else "\n".join(perde.map(func(e): return nome_evento(dados.evento(e)))),
			FONTE_PEQUENA + 2, Color.WHITE if not perde.is_empty() else COR_SECUNDARIA, q)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _janela_pecas(c: Carro, cat: String, v: VBoxContainer) -> void:
	var attr: String = PecasTexto.AFETA_CATEGORIA.get(cat, "potencia")
	_descritivo(v, PecasTexto.FUNCAO[attr])
	var pecas := _itens(c, cat)
	# O ganho de cada estágio é sobre a categoria vazia (não sobre o estágio em
	# uso): o 1 sempre mostra o que ele dá, mesmo com o 3 instalado.
	var sem := c.copiar()
	sem.remover(cat)
	var base_cat := sem.atributos_efetivos("seco")
	var escolhido := _escolhido(c, cat)
	for p in pecas:
		var instalada: bool = c.pecas.get(cat, {}).get("id") == p["id"]
		var teste := c.copiar()
		teste.instalar(p)
		var ganho := "" if cat == "cambio" else _ganho(base_cat, teste.atributos_efetivos("seco"))
		var texto := String(p["nome"]) + ("   " + ganho if ganho != "" else "")
		if instalada:
			texto += "   · EM USO"
		elif p["id"] in c.pecas_possuidas:
			texto += "   ✓"
		var b := _item_evolucao(v, c, cat, String(p["id"]), texto, "uso" if instalada else "", p["id"] == escolhido.get("id"))
		if p["id"] == String(dados.historia().get("adrian", {}).get("peca_demanda", "")) or (cat == "brake"
				and not ancoras.has("BRAKES")):
			ancora("BRAKES", b)
	if cat == "cambio" and c.pecas.has("cambio"):
		var aj := HBoxContainer.new()
		aj.add_theme_constant_override("separation", 8)
		v.add_child(aj)
		for a in PecasTexto.AJUSTES_CAMBIO:
			var b := botao(a[1], func():
				c.ajuste_cambio = a[0]
				_reabrir(c, cat), true, c.ajuste_cambio == a[0], aj)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var perde := []
	if not escolhido.is_empty() and c.pecas.get(cat, {}).get("id") != escolhido["id"]:
		var teste := c.copiar()
		teste.instalar(escolhido)
		var depois := Mecanico.provas_possiveis(dados, teste)
		perde = Mecanico.provas_possiveis(dados, c).filter(func(e): return not e in depois)
	_proibicoes(v, perde)
	if _correndo(c):
		rotulo("Correndo: o que mudar aqui vale para as próximas corridas.", FONTE_PEQUENA + 2, COR_INFO, v)


func _janela_pneus(c: Carro, v: VBoxContainer) -> void:
	_descritivo(v, PecasTexto.FUNCAO["pneu"])
	var escolhido := _escolhido(c, "pneus")
	for pn in dados.lista("pneus"):
		var tem: bool = c.pneus.any(func(x): return x["id"] == pn["id"])
		var texto := "%s   ader. %d" % [pn["nome"], roundi(pn["aderencia"]["seco"] * 100.0)] + ("   ✓" if tem else "")
		_item_evolucao(v, c, "pneus", String(pn["id"]), texto, "uso" if tem else "", pn["id"] == escolhido.get("id"))
	_proibicoes(v, [])


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
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = COR_DESTAQUE
	sb.border_width_left = 4
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	var sb_toque := sb.duplicate()
	sb_toque.bg_color = Color(0, 0, 0, 0.6)
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


## Janela GARAGEM (aba pendurada no cabeçalho): vagas e ampliação no topo,
## os carros em ícones ou lista; tocar num carro o leva para a Oficina; cada
## um pode ser vendido aqui.
func abrir_garagem() -> void:
	var botoes := []
	var amp := _ampliacao()
	if not amp.is_empty():
		botoes.append(amp)
	painel_estilo.emit("GARAGEM", func(v):
		_colecao(v, jogador.garagem.lista(), carro_ativo()), botoes,
		{"fora_fecha": true, "titulo_max": 64, "principal": true, "titulo_extra": _cabecalho_garagem,
		"habilitado": amp.is_empty() or jogador.economia.pode_pagar(_preco_ampliacao())})


func _reabrir_garagem() -> void:
	abrir_garagem.call_deferred()


## Cabeçalho da janela: ocupação ao lado do título, modos de exibição à direita.
func _cabecalho_garagem(h: HBoxContainer) -> void:
	var n: int = jogador.garagem.lista().size()
	var cap: int = jogador.garagem.vagas
	var cont := Label.new()
	cont.text = "  %d%s CARRO%s" % [n, "/%d" % cap if cap > 0 else "", "" if n == 1 and cap <= 0 else "S"]
	Tipografia.rotulo(cont, "medium", 28)
	cont.add_theme_color_override("font_color", COR_RUIM if jogador.garagem.cheia() else COR_SECUNDARIA)
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cont)
	for modo in [["grade", false], ["lista", true]]:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 52)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = "Ícones" if not modo[1] else "Lista"
		var ic := IconeVetor.new(modo[0], COR_DESTAQUE if Preferencias.garagem_lista == modo[1] else COR_SECUNDARIA)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 10
		ic.offset_right = -10
		ic.offset_top = 10
		ic.offset_bottom = -10
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		b.pressed.connect(func():
			Preferencias.garagem_lista = modo[1]
			Preferencias.salvar()
			_reabrir_garagem())
		h.add_child(b)
	var traco := ColorRect.new()
	traco.color = Color(1, 1, 1, 0.15)
	traco.custom_minimum_size = Vector2(2, 44)
	traco.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(traco)


## Coleção: cartões em 2 colunas (padrão) ou lista (para garagens grandes).
func _colecao(pai: VBoxContainer, lista: Array, ativo: Carro) -> void:
	if lista.is_empty():
		rotulo("Nenhum carro ainda: compre nas Lojas.", FONTE_PEQUENA + 2, COR_SECUNDARIA, pai)
		return
	if Preferencias.garagem_lista:
		for c in lista:
			_linha_carro(pai, c, ativo != null and c.uid == ativo.uid)
		return
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	pai.add_child(g)
	for c in lista:
		_cartao_carro(g, c, ativo != null and c.uid == ativo.uid)


const ALTURA_CARTAO_GARAGEM := 370
const LARGURA_NOME_GARAGEM := 270.0


## Cartão da grade: selo EM USO, o carro grande, o nome e o vender no rodapé.
## Tocar no cartão leva o carro para a Oficina.
func _cartao_carro(pai: Control, c: Carro, em_uso: bool) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ALTURA_CARTAO_GARAGEM)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, _estilo_item(em_uso))
	b.pressed.connect(_escolher.bind(c))
	pai.add_child(b)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 10
	v.offset_bottom = -6
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var selo := HBoxContainer.new()
	selo.custom_minimum_size = Vector2(0, 36)
	selo.add_theme_constant_override("separation", 8)
	selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(selo)
	if em_uso:
		var vao := Control.new()
		vao.custom_minimum_size = Vector2(10, 0)
		vao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selo.add_child(vao)
		var ok := IconeVetor.new("check", COR_DESTAQUE)
		ok.custom_minimum_size = Vector2(28, 28)
		ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selo.add_child(ok)
		var l := Label.new()
		l.text = "EM USO"
		Tipografia.rotulo(l, "semibold", 24)
		l.add_theme_color_override("font_color", COR_DESTAQUE)
		selo.add_child(l)
	var img := icone_carro(c.base, false, CarroBloco.cor_do_carro(c))
	img.custom_minimum_size = Vector2(0, 200)
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	var nome := Label.new()
	nome.text = c.base["nome"]
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.custom_minimum_size = Vector2(0, 56)
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Tipografia.rotulo(nome, "semibold", 34)
	var f := nome.get_theme_font("font")
	var tam := 34
	while tam > 20 and f.get_string_size(nome.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > LARGURA_NOME_GARAGEM:
		tam -= 2
	nome.add_theme_font_size_override("font_size", tam)
	nome.clip_text = true
	nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nome)
	var vender := _botao_vender(v, c)
	vender.custom_minimum_size = Vector2(0, 64)


## Escolher um carro na janela: ele vai para a Oficina e a janela fecha.
func _escolher(c: Carro) -> void:
	jogador.carro_ativo = c.uid
	fechar_painel.emit()
	mudou.emit()


func _botao_vender(pai: Control, c: Carro) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = _correndo(c) or not jogador.concessionaria.pode_vender(c.uid) or Prologo.carro_travado(dados, jogador, c)
	Tipografia.acao_neutra(b, "VENDER · %s" % dinheiro(revenda(c.base)), 24, 52)
	moeda(b, 24)
	b.pressed.connect(_confirmar_venda.bind(c))
	pai.add_child(b)
	return b


func _estilo_item(ativo: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(8)
	sb.border_color = COR_DESTAQUE if ativo else Color(1, 1, 1, 0.08)
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 12
	return sb


## Uma linha da lista: foto pequena, nome, o essencial e vender.
func _linha_carro(pai: Control, c: Carro, ativo: bool) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	pai.add_child(linha)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	img.custom_minimum_size = Vector2(110, 76)
	h.add_child(img)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", -2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(info)
	var nome := Label.new()
	nome.text = c.base["nome"]
	nome.clip_text = true
	nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tipografia.rotulo(nome, "semibold", 26)
	info.add_child(nome)
	var a := c.atributos_efetivos("seco")
	var num := Label.new()
	num.text = "%d cv · %d kg" % [roundi(a["potencia"]), roundi(a["peso"])]
	Tipografia.numero(num, 18)
	num.add_theme_color_override("font_color", COR_SECUNDARIA)
	info.add_child(num)
	b.pressed.connect(_escolher.bind(c))
	linha.add_child(b)
	var vender := _botao_vender(linha, c)
	vender.size_flags_horizontal = Control.SIZE_SHRINK_END
	vender.custom_minimum_size = Vector2(180, 84)


## Ampliar a garagem (dobra as vagas, cada vez mais caro: VagasGaragem): a
## ação principal da janela. [] quando não há ampliação.
func _ampliacao() -> Array:
	if jogador.garagem.vagas <= 0 or _preco_ampliacao() <= 0:
		return []
	var nova := VagasGaragem.capacidade(dados, jogador.ampliacoes_garagem + 1)
	return ["AMPLIAR PARA %d VAGAS · %s" % [nova, dinheiro(_preco_ampliacao())], func():
		var erro := VagasGaragem.ampliar(dados, jogador)
		if erro != "":
			avisar("Não deu: %s." % erro, false)
		else:
			avisar("Garagem com %d vagas." % jogador.garagem.vagas)
		mudou.emit()
		_reabrir_garagem(), "giros"]


func _preco_ampliacao() -> int:
	return VagasGaragem.preco(dados, jogador.ampliacoes_garagem)


func _confirmar_venda(c: Carro) -> void:
	painel.emit("Vender %s?" % c.base["nome"], func(v):
		v.add_child(Estudio.imagem(c.base, CarroBloco.cor_do_carro(c), Vector2(0, 180)))
		nota("icone_vender", "Você recebe %s giros" % dinheiro(revenda(c.base)), "", v, Color.WHITE)
		rotulo("Peças instaladas não entram no valor.", FONTE_PEQUENA, COR_SECUNDARIA, v),
		[["Vender", func():
			_vender(c.uid)
			mudou.emit()
			_reabrir_garagem()], ["Cancelar", _reabrir_garagem]])


func _vender(uid: int) -> void:
	if not jogador.concessionaria.pode_vender(uid):
		avisar("O único carro da garagem não pode ser vendido.", false)
		return
	var nome: String = jogador.garagem.carro(uid).base["nome"]
	avisar("Vendido: %s por %s giros." % [nome, dinheiro(jogador.concessionaria.vender_carro(uid))])
	if jogador.carro_ativo == uid:
		jogador.carro_ativo = -1


## Garagem vazia e nenhum carro das Lojas cabe no saldo.
func _sem_saida() -> bool:
	return dados.lista("carros").all(func(c): return not jogador.economia.pode_pagar(int(c["preco"])))


func _recomecar() -> void:
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	avisar("Carreira recomeçada com %s giros." % dinheiro(jogador.economia.saldo))
