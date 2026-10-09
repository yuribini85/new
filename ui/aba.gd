class_name Aba
extends ScrollContainer
## Base das abas: conteúdo rolável, reconstruído inteiro em atualizar().
## Arte da interface em res://arte/ui/ (docs/linguagem.md): ícones, miniaturas,
## banners e fundos; sem o arquivo, o componente aparece sem a imagem.
##
## Linguagem visual comum a todas as telas: cabeçalho com uma frase do que se
## faz ali, cartões, selos coloridos para estado, barras para atributos, uma
## dica de "como funciona" e um botão de próximo passo.

signal mudou
## Pede à tela principal para abrir outra aba (índices em ABAS).
signal ir_para(indice: int)
## Aviso curto no topo: confirmação (ok) ou motivo de uma falha.
signal aviso(texto: String, ok: bool)
## Painel modal com rolagem (Sobreposicao.abrir).
signal painel(titulo: String, montar: Callable, botoes: Array)

enum { GARAGEM, LOJA, OFICINA, EVENTOS, CORRIDA, LICENCAS }

const FONTE_PEQUENA := 23
const FONTE_TITULO := 40
## Botão com ícone: o ícone é o que o jogador lê primeiro (para onde vai), então
## fica maior que o texto, que vem menor ao lado.
const ICONE_BOTAO := 64
const FONTE_BOTAO_ICONE := 26
## Paleta das telas de referência (docs/referencias/ui_*.webp).
const COR_FUNDO := Color(0.078, 0.09, 0.11)
const COR_CARTAO := Color(0.118, 0.133, 0.157)
const COR_SECUNDARIA := Color(0.77, 0.79, 0.85)
const COR_DESTAQUE := Color("d6a23e")  # ocre mostarda
const COR_BOM := Color(0.36, 0.82, 0.47)
const COR_RUIM := Color(1.0, 0.46, 0.4)
const COR_INFO := Color(0.45, 0.7, 1.0)
const COR_NEUTRA := Color(0.4, 0.42, 0.48)
## Acima disto, o selo quebra linha em faixa própria.
const LIMITE_SELO := 26

var dados: Node
var jogador: Node
var conteudo: VBoxContainer
## Âncoras dos destaques do tutorial (HIGHLIGHT_<nome> das cenas): nome ->
## controle da tela atual. Refeitas a cada construir().
var ancoras: Dictionary = {}
## Altura da faixa do cabeçalho (Cabecalho): o conteúdo começa abaixo dela.
var topo_livre := 0.0
const MARGEM_LATERAL := 16


func _init(dados_: Node, jogador_: Node, titulo_aba: String) -> void:
	dados = dados_
	jogador = jogador_
	name = titulo_aba
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# O arrasto do próprio ScrollContainer só começa em área vazia (os botões
	# ficam com o toque); a rolagem por arrasto é a de _input, abaixo.
	scroll_deadzone = 100000
	conteudo = VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation", 14)
	# A aba vai de borda a borda (o cenário sangra até a beira da tela); o
	# conteúdo tem a margem lateral.
	var lados := MarginContainer.new()
	lados.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lados.add_theme_constant_override("margin_left", MARGEM_LATERAL)
	lados.add_theme_constant_override("margin_right", MARGEM_LATERAL)
	add_child(lados)
	lados.add_child(conteudo)


## Reconstrói a tela mantendo a posição da lista (voltar não perde o lugar).
func atualizar() -> void:
	var posicao := scroll_vertical
	for c in conteudo.get_children():
		conteudo.remove_child(c)
		c.queue_free()
	ancoras = {}
	construir()
	_espaco_topo()
	if posicao > 0:
		set_deferred("scroll_vertical", posicao)


## Implementado por cada aba.
func construir() -> void:
	pass


# --- Rolagem pelo dedo -------------------------------------------------------
# O dedo pode começar em qualquer ponto da aba, até em cima de um botão: depois
# de LIMIAR_ARRASTO px o toque vira rolagem, e o botão não é
# acionado (a soltura vai para fora da tela). Ao soltar, a lista ainda desliza
# um pouco (inércia). Arrasto de lado rola a lista horizontal sob o dedo
# (miniaturas, filtros); sliders seguem com o próprio arrasto. Apresentação,
# não balanceamento.
const LIMIAR_ARRASTO := 14.0
const ATRITO := 4.0  # por segundo: quanto a inércia perde
var _toque := false
var _arrastando := false
var _inicio := Vector2.ZERO
var _ultimo := Vector2.ZERO
var _ultimo_t := 0.0
var _velocidade := 0.0
## O que o arrasto rola: esta aba (vertical) ou uma lista de lado dentro dela.
var _alvo: ScrollContainer
var _horizontal := false


const FORA := Vector2(-10000, -10000)


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		_toque = false
		_arrastando = false
		return
	if e is InputEventMouse and e.position.x < FORA.x / 2.0:
		return  # os eventos "fora da tela" que esta rolagem manda passam direto
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_toque = get_global_rect().has_point(e.position)
			_arrastando = false
			_inicio = e.position
			_ultimo = e.position
			_ultimo_t = Time.get_ticks_msec() / 1000.0
			_velocidade = 0.0
		elif _toque:
			_toque = false
			if _arrastando:
				_arrastando = false
				get_viewport().set_input_as_handled()
				# Solta fora da tela: o botão onde o dedo começou não é acionado.
				var fora: InputEventMouseButton = e.duplicate()
				fora.position = FORA
				fora.global_position = FORA
				Input.parse_input_event(fora)
	elif e is InputEventMouseMotion and _toque:
		var d: Vector2 = e.position - _inicio
		if not _arrastando:
			if maxf(absf(d.x), absf(d.y)) < LIMIAR_ARRASTO:
				return
			var sob := get_viewport().gui_get_hovered_control()
			if sob != null and sob != self and not is_ancestor_of(sob):
				_toque = false  # o dedo está em outra camada (diálogo, barra)
				return
			if sob is Range:
				_toque = false  # slider segue com o próprio arrasto
				return
			_horizontal = absf(d.x) > absf(d.y)
			_alvo = _lista_de_lado(sob) if _horizontal else self
			if _alvo == null:
				_toque = false  # de lado, fora de uma lista que rola de lado
				return
			_arrastando = true
			_ultimo = e.position
			# O botão sob o dedo só desiste do toque vendo o dedo sair dele.
			var saiu: InputEventMouseMotion = e.duplicate()
			saiu.position = FORA
			saiu.global_position = FORA
			Input.parse_input_event(saiu)
		var agora := Time.get_ticks_msec() / 1000.0
		var dv: float = (e.position.x - _ultimo.x) if _horizontal else (e.position.y - _ultimo.y)
		_rolar(dv)
		if agora > _ultimo_t:
			_velocidade = lerpf(_velocidade, dv / (agora - _ultimo_t), 0.5)
		_ultimo = e.position
		_ultimo_t = agora
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _toque or absf(_velocidade) < 20.0 or not is_instance_valid(_alvo):
		return
	_rolar(_velocidade * delta)
	_velocidade *= exp(-ATRITO * delta)


func _rolar(d: float) -> void:
	if _horizontal:
		_alvo.scroll_horizontal -= int(round(d))
	else:
		_alvo.scroll_vertical -= int(round(d))


## Lista que rola de lado contendo o controle (miniaturas, filtros), ou null.
func _lista_de_lado(c: Node) -> ScrollContainer:
	var n := c
	while n != null and n != self:
		if n is ScrollContainer and n.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return n
		n = n.get_parent()
	return null


func reservar_topo(altura: float) -> void:
	topo_livre = altura


## Marca `c` como cenário do topo: sem cantos nem moldura, da beira à beira da
## tela (os filhos de tela cheia passam a margem lateral).
func cenario_topo(c: Control) -> void:
	c.set_meta("cenario_topo", true)
	c.clip_contents = false
	if c is Panel:
		c.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for f in c.get_children():
		if f is Control and f.anchor_left == 0.0 and f.anchor_right == 1.0 and f.anchor_top == 0.0 \
				and f.anchor_bottom == 1.0:
			f.offset_left = -MARGEM_LATERAL
			f.offset_right = MARGEM_LATERAL


## O conteúdo começa logo abaixo da faixa do cabeçalho; o cenário do topo
## (banner, palco) fica colado nela, de borda a borda.
func _espaco_topo() -> void:
	if topo_livre <= 0.0 or conteudo.get_child_count() == 0:
		return
	var vazio := Control.new()
	vazio.custom_minimum_size = Vector2(0, topo_livre - 14.0)  # 14: o espaço entre itens
	vazio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_child(vazio)
	conteudo.move_child(vazio, 0)


## Marca um controle como alvo do destaque `nome` (o primeiro registrado vale).
## Um cartão marca o painel inteiro.
func ancora(nome: String, c: Control) -> void:
	if ancoras.has(nome):
		return
	ancoras[nome] = c.get_parent() if c is VBoxContainer and c.get_parent() is PanelContainer else c


## Antes do destaque: a aba muda o que mostra para a âncora existir (ex.: a
## Oficina abre o grupo do chassi para os freios). Implementado onde precisa.
func preparar_destaque(_nome: String) -> void:
	pass


# --- Blocos de tela ---------------------------------------------------------

## Título da tela e uma frase dizendo o que se faz nela. Com `fundo` (arte da
## interface), o título vai sobre a ilustração, escurecida embaixo.
func cabecalho(t: String, subtitulo := "", fundo := "") -> void:
	var tex := arte(fundo) if fundo != "" else null
	if tex == null:
		rotulo(t, FONTE_TITULO)
		if subtitulo != "":
			rotulo(subtitulo, FONTE_PEQUENA, COR_SECUNDARIA)
		return
	# O título fica no cabeçalho; o banner é o cenário do topo, com a frase.
	var faixa := ilustracao(fundo, 150 if subtitulo != "" else 120)
	cenario_topo(faixa)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	v.offset_left = 20
	v.offset_right = -20
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 0)
	faixa.add_child(v)
	if subtitulo != "":
		var l := rotulo(subtitulo, FONTE_PEQUENA + 2, Color(0.9, 0.91, 0.94), v)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))


# --- Arte da interface ------------------------------------------------------

const PASTA_ARTE := "res://arte/ui/"
static var _arte := {}


## Textura da arte da interface (arte/ui/<nome>.png); null se não existe.
static func arte(nome: String) -> Texture2D:
	if not _arte.has(nome):
		var caminho := PASTA_ARTE + nome + ".png"
		_arte[nome] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _arte[nome]


## Ícone da interface num quadrado de `tamanho` px.
func icone(nome: String, tamanho := 44, pai: Control = null) -> TextureRect:
	var t := TextureRect.new()
	t.texture = arte(nome)
	t.custom_minimum_size = Vector2(tamanho, tamanho)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if pai != null:
		pai.add_child(t)
	return t


## Ilustração (banner, fundo, miniatura) cobrindo a largura, com altura fixa,
## cantos arredondados e escurecida embaixo para texto por cima.
func ilustracao(nome: String, altura: float, pai: Control = null, escurecer := 0.75) -> Control:
	var caixa := Panel.new()
	caixa.custom_minimum_size = Vector2(0, altura)
	caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(12)
	caixa.add_theme_stylebox_override("panel", sb)
	var t := TextureRect.new()
	t.texture = arte(nome)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(t)
	if escurecer > 0.0:
		var g := TextureRect.new()
		var grad := GradientTexture2D.new()
		grad.fill_from = Vector2(0, 0)
		grad.fill_to = Vector2(0, 1)
		var gr := Gradient.new()
		gr.set_color(0, Color(COR_FUNDO, 0.0))
		gr.set_color(1, Color(COR_FUNDO, escurecer))
		grad.gradient = gr
		g.texture = grad
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caixa.add_child(g)
	_pai(pai).add_child(caixa)
	return caixa


## Atributos do carro em quatro quadros (ícone, número, onde ajuda e barra),
## como na referência da garagem. A barra é só leitura relativa ao catálogo.
## `antes`: valores anteriores (mostra a diferença em verde/vermelho).
## Pneus e freios são fatores (1,0 = o carro de fábrica): mostrados como a
## diferença para o de fábrica, que é o que o jogador compara.
## Equipes rivais que correm com o modelo: as dos níveis das provas em que
## ele está no grid (a escalação sorteia entre elas, decisão 36).
func equipes_do_carro(carro_id: String) -> Array:
	var cfg: Dictionary = dados.carreira()
	var niveis: Array = cfg.get("niveis", [])
	var mapa: Dictionary = cfg.get("niveis_licenca", {})
	var usados := {}
	for ev in dados.lista("eventos"):
		if ev["adversarios"].any(func(x): return x["carro"] == carro_id):
			var lic := String(ev["restricoes"].get("licenca", ""))
			usados[String(mapa.get(lic, niveis[0] if not niveis.is_empty() else ""))] = true
	var r := []
	for e in dados.lista("equipes"):
		if usados.has(String(e.get("nivel", ""))):
			r.append(String(e["nome"]))
	return r


static func texto_fator(v: float, curto := false) -> String:
	var pct := roundi((v - 1.0) * 100.0)
	return ("Original" if curto else "original") if pct == 0 else "%+d%%" % pct


func atributos_carro(a: Dictionary, pai: Control = null, antes: Dictionary = {}) -> GridContainer:
	var max_cv := 1.0
	var max_kg := 1.0
	for c in dados.lista("carros"):
		max_cv = maxf(max_cv, float(c["potencia"]))
		max_kg = maxf(max_kg, float(c["peso"]))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var itens := [
		["icone_potencia", "%d" % a["potencia"], "cv · retas", a["potencia"] / (max_cv * 1.4), COR_DESTAQUE, "potencia", false],
		["icone_peso", "%d" % a["peso"], "kg · menos é melhor", 1.0 - a["peso"] / (max_kg * 1.25), COR_INFO, "peso", true],
		["icone_pneus", texto_fator(a.get("aderencia", 1.0)), "pneus · aderência", (a.get("aderencia", 1.0) - 0.7) / 0.8,
				COR_BOM, "aderencia", false],
		["icone_freios", texto_fator(a.get("freio", 1.0)), "freios · frenagem", (a.get("freio", 1.0) - 0.7) / 0.9,
				COR_RUIM.lerp(COR_DESTAQUE, 0.5), "freio", false],
	]
	for it in itens:
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_CARTAO
		sb.border_color = Color(1, 1, 1, 0.06)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(10)
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		p.add_child(v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		v.add_child(h)
		icone(it[0], 52, h)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", -4)
		h.add_child(tv)
		var n := Label.new()
		n.text = it[1]
		n.add_theme_font_size_override("font_size", 36)
		if antes.has(it[5]) and not is_equal_approx(float(antes[it[5]]), float(a[it[5]])):
			var d := float(a[it[5]]) - float(antes[it[5]])
			var melhora: bool = (d > 0.0) != bool(it[6])
			n.add_theme_color_override("font_color", COR_BOM if melhora else COR_RUIM)
		tv.add_child(n)
		var u := Label.new()
		u.text = it[2]
		u.add_theme_font_size_override("font_size", FONTE_PEQUENA - 3)
		u.add_theme_color_override("font_color", COR_SECUNDARIA)
		tv.add_child(u)
		var trilho := ProgressBar.new()
		trilho.show_percentage = false
		trilho.custom_minimum_size = Vector2(0, 10)
		trilho.max_value = 1.0
		trilho.value = clampf(it[3], 0.04, 1.0)
		var fundo_b := StyleBoxFlat.new()
		fundo_b.bg_color = Color(1, 1, 1, 0.08)
		fundo_b.set_corner_radius_all(4)
		var cheio := StyleBoxFlat.new()
		cheio.bg_color = it[4]
		cheio.set_corner_radius_all(4)
		trilho.add_theme_stylebox_override("background", fundo_b)
		trilho.add_theme_stylebox_override("fill", cheio)
		v.add_child(trilho)
		g.add_child(p)
	_pai(pai).add_child(g)
	return g


## Cartão com fundo arredondado; `acento` pinta a borda esquerda (estado).
## Retorna o VBox de dentro, onde vai o conteúdo.
func cartao(acento := Color.TRANSPARENT, pai: Control = null) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	if acento.a > 0.0:
		sb.border_width_left = 8
		sb.border_color = acento
		sb.content_margin_left = 22
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	_pai(pai).add_child(p)
	return v


# --- Explicação curta -------------------------------------------------------
# Regra (docs/linguagem.md): na tela, ícone + uma frase curta (até ~40
# caracteres); o porquê e o detalhe ficam atrás do botão ⓘ, num painel.

## Linha de nota: ícone, frase curta e, com `detalhe`, o botão ⓘ que abre o
## texto completo (não usar `detalhe` dentro de um painel: abriria outro). Ícone que ainda não existe na arte: a linha fica sem ele.
func nota(nome_icone: String, curta: String, detalhe := "", pai: Control = null, cor := COR_SECUNDARIA) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	if nome_icone != "" and arte(nome_icone) != null:
		icone(nome_icone, 38, h)
	var l := rotulo(curta, FONTE_PEQUENA + 1, cor, h)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if detalhe != "":
		# Frase curta numa linha só, com o ⓘ colado nela (rótulo com quebra e
		# sem expandir ficaria com largura zero: uma letra por linha).
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		botao_info(curta, detalhe, h)
	_pai(pai).add_child(h)
	return h


## Título de seção (MAIÚSCULAS, pequeno) com ⓘ opcional ao lado.
func titulo_secao(t: String, detalhe := "", pai: Control = null, cor := COR_SECUNDARIA) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := rotulo(t, FONTE_PEQUENA, cor, h)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if detalhe != "":
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		botao_info(t.capitalize() if t == t.to_upper() else t, detalhe, h)
	_pai(pai).add_child(h)
	return h


## Botão ⓘ: abre um painel com o detalhe. Área de toque de 56 px.
func botao_info(titulo_painel: String, detalhe: String, pai: Control = null) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(56, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = "Saiba mais"
	var tex := icone_reduzido("icone_info", 36)
	if tex != null:
		b.icon = tex
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		b.text = "ⓘ"
		b.add_theme_color_override("font_color", COR_INFO)
	b.pressed.connect(func():
		painel.emit(titulo_painel, func(v):
			rotulo(detalhe, FONTE_PEQUENA + 3, Color.WHITE, v), []))
	_pai(pai).add_child(b)
	return b


## Caixa "como funciona": explica a tela para quem chega nela pela primeira vez.
func dica(t: String, pai: Control = null) -> VBoxContainer:
	var v := cartao(COR_INFO, pai)
	rotulo("COMO FUNCIONA", FONTE_PEQUENA, COR_INFO, v)
	rotulo(t, FONTE_PEQUENA + 3, Color(0.88, 0.9, 0.95), v)
	return v


## Cartão de próximo passo com um botão que leva à aba certa.
func proximo_passo(t: String, botao_texto: String, indice: int, pai: Control = null) -> void:
	var v := cartao(COR_DESTAQUE, pai)
	rotulo("PRÓXIMO PASSO", FONTE_PEQUENA, COR_DESTAQUE, v)
	rotulo(t, FONTE_PEQUENA + 3, Color.WHITE, v)
	botao(botao_texto, func(): ir_para.emit(indice), true, true, v)


## Painel com a ficha de um modelo: vitrine 3D, fabricante, números e como
## conseguir (novo, usado, prêmio de qual prova).
## Ficha do modelo: vitrine grande, números, comparação com o carro em uso,
## como conseguir e fabricante. `extras`: selos a mais ([[texto, cor]]);
## `compra`: [texto, Callable, habilitado] vira o botão principal do painel.
## `cor`: pintura mostrada (usado: a cor dele); sem ela, a de fábrica.
## `escolher_cor`: carro novo, como no GT2: as cores do modelo para escolher;
## a escolhida fica em `cor_escolhida` (hex) para o Callable da compra.
var cor_escolhida := ""


func ficha_modelo(base: Dictionary, extras: Array = [], compra: Array = [], cor := Color(0, 0, 0, 0),
		escolher_cor := false) -> void:
	var inicial: Color = cor if cor.a > 0.0 else Cores.fabrica(String(base["id"]))
	cor_escolhida = inicial.to_html(false)
	var botoes := [] if compra.is_empty() or not compra[2] else [[compra[0], func():
		compra[1].call()
		mudou.emit()], ["Fechar", func(): pass]]
	painel.emit(base["nome"], func(v):
		var vit := VitrineCarro.new(320.0)
		vit.mostrar_modelo(base, inicial)
		v.add_child(vit)
		if escolher_cor:
			_amostras_cor(base, vit, v)
		var fab: Dictionary = dados.item("fabricantes", base["fabricante"])
		rotulo("%s%s · %s" % [fab.get("nome", ""), " · %d" % base["ano"] if int(base["ano"]) > 0 else "",
				NOMES_CATEGORIA_CARRO.get(base.get("categoria", ""), "")],
				FONTE_PEQUENA + 2, COR_SECUNDARIA, v)
		numeros([["%d" % base["potencia"], "cv"], ["%d" % base["peso"], "kg"], [base["tracao"], "tração"]], v)
		var meu := carro_ativo()
		var comp := []
		if meu != null and meu.id != base["id"]:
			var a := meu.atributos_efetivos("seco")
			comp.append(["vs seu %s: %+d cv, %+d kg" % [meu.base["nome"], int(base["potencia"]) - roundi(a["potencia"]),
					int(base["peso"]) - roundi(a["peso"])], COR_INFO])
			# Potência por peso: mais cv com muito mais peso pode não valer a pena.
			comp.append(["potência por tonelada: %d cv (o seu: %d)" % [roundi(1000.0 * float(base["potencia"]) / float(base["peso"])),
					roundi(1000.0 * a["potencia"] / a["peso"])], COR_INFO])
		else:
			comp.append(["potência por tonelada: %d cv" % roundi(1000.0 * float(base["potencia"]) / float(base["peso"])),
					COR_NEUTRA.lightened(0.3)])
		selos(extras + comp, v)
		if not compra.is_empty() and not compra[2]:
			rotulo(compra[0], FONTE_PEQUENA + 2, COR_RUIM, v)
		var como := []
		if base.get("novo", true):
			como.append("novo no Mercado por %s G" % dinheiro(int(base["preco"])))
		if not base.get("usados", []).is_empty():
			como.append("usado em alguns períodos")
		for ev in dados.lista("eventos"):
			if ev.get("carro_premio") == base["id"]:
				como.append("prêmio da 1ª vitória em %s" % ev["nome"])
		if como.is_empty():
			como.append("ainda não disponível")
		var equipes := equipes_do_carro(String(base["id"]))
		var ve := cartao(Color.TRANSPARENT, v)
		rotulo("EQUIPES QUE CORREM COM ELE", FONTE_PEQUENA, COR_SECUNDARIA, ve)
		rotulo(", ".join(equipes) + "." if not equipes.is_empty() else "Nenhuma equipe rival usa este modelo.",
				FONTE_PEQUENA + 2, Color.WHITE, ve)
		var raro: bool = not base.get("novo", true) and base.get("usados", []).is_empty()
		var vc := cartao(COR_DESTAQUE if raro else Color.TRANSPARENT, v)
		rotulo("COMO CONSEGUIR" + (" · RARO" if raro else ""), FONTE_PEQUENA, COR_DESTAQUE if raro else COR_SECUNDARIA, vc)
		rotulo("; ".join(como).capitalize().left(1) + "; ".join(como).substr(1) + ".", FONTE_PEQUENA + 2, Color.WHITE, vc)
		rotulo("Revenda depois: %s G" % dinheiro(revenda(base)), FONTE_PEQUENA, COR_SECUNDARIA, vc)
		if not base.get("usados", []).is_empty():
			var desejado: bool = base["id"] in jogador.desejos
			var bd := botao_texto("♥ Avisando quando aparecer usado (parar)" if desejado else "♡ Avisar quando aparecer usado", func():
				if desejado:
					jogador.desejos.erase(base["id"])
				else:
					jogador.desejos.append(base["id"])
				mudou.emit(), vc)
			bd.pressed.connect(func(): bd.text = "Feito: veja as próximas ofertas no Mercado")
		if not fab.is_empty():
			var vf := cartao(Color.TRANSPARENT, v)
			rotulo("%s · %s" % [fab.get("nome", ""), fab.get("pais", "")], 0, Color.WHITE, vf)
			rotulo(fab.get("historia", ""), FONTE_PEQUENA + 2, COR_SECUNDARIA, vf), botoes)


## Entrega de um carro novo: o carro girando e o próximo passo.
func entrega(carro: Carro) -> void:
	painel.emit("Seu novo carro", func(v):
		var vit := VitrineCarro.new(380.0)
		vit.mostrar_modelo(carro.base, CarroBloco.cor_do_carro(carro))
		v.add_child(vit)
		var n := rotulo(carro.base["nome"], 44, Color.WHITE, v)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var a := carro.atributos_efetivos("seco")
		numeros([["%d" % a["potencia"], "cv"], ["%d" % a["peso"], "kg"], [carro.base["tracao"], "tração"]], v),
		[["Ir para a garagem", func():
			jogador.carro_ativo = carro.uid
			ir_para.emit(GARAGEM)
			mudou.emit()], ["Continuar comprando", func(): pass]])


## Nome do modelo sem o fabricante ("Hayase Tsubame" -> "Tsubame"), para
## miniaturas onde o espaço é curto.
static func nome_curto(nome: String) -> String:
	var partes := nome.split(" ", true, 1)
	return partes[1] if partes.size() > 1 else nome


## Quanto a Loja paga por este modelo na venda (preço de tabela × fração).
func revenda(base: Dictionary) -> int:
	return int(floor(float(base["preco"]) * float(dados.economia()["fracao_revenda"])))


## Botão pequeno que abre o painel "Entenda os números" (glossário).
func entenda(pai: Control = null) -> void:
	var b := botao("Entenda os números", func():
		painel.emit("Entenda os números", func(v):
			for g in Objetivos.glossario(dados):
				var c := cartao(Color.TRANSPARENT, v)
				rotulo(g[0], 30, COR_DESTAQUE, c)
				rotulo(g[1], FONTE_PEQUENA + 3, Color.WHITE, c), []),
			true, false, pai)
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", FONTE_PEQUENA)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END


func rotulo(t: String, tamanho := 0, cor := Color.WHITE, pai: Control = null) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tamanho > 0:
		l.add_theme_font_size_override("font_size", tamanho)
	if cor != Color.WHITE:
		l.add_theme_color_override("font_color", cor)
	_pai(pai).add_child(l)
	return l


## Etiqueta pequena colorida ("EM USO", "Chuva", "✓ pode correr").
func selo(t: String, cor: Color, pai: Control = null) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(cor, 0.2)
	sb.border_color = cor
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", FONTE_PEQUENA)
	l.add_theme_color_override("font_color", cor.lightened(0.25))
	p.add_child(l)
	_pai(pai).add_child(p)
	return p


## Fileira de selos que quebra linha: selos = [[texto, cor], ...]. Textos
## longos viram uma faixa própria com quebra de linha, para nunca alargar a tela.
func selos(lista: Array, pai: Control = null) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 6)
	v.add_child(h)
	for s in lista:
		if String(s[0]).length() > LIMITE_SELO:
			var p := selo(s[0], s[1], v)
			var l: Label = p.get_child(0)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			selo(s[0], s[1], h)
	_pai(pai).add_child(v)
	return v


## Avisa a tela principal (aviso no topo).
## Dispara um trigger da história (Historia); true se uma cena foi pedida.
func historia(trigger: String, ctx: Dictionary = {}) -> bool:
	return jogador.historia != null and jogador.historia.disparar(trigger, ctx)


func avisar(t: String, ok := true) -> void:
	aviso.emit(t, ok)


## Põe o ícone no botão, em cima e maior que o texto (ICONE_BOTAO); o texto
## vem menor, embaixo, como na barra de navegação.
static func com_icone(b: Button, nome_icone: String, tamanho := ICONE_BOTAO) -> void:
	var tex := icone_reduzido(nome_icone, tamanho)
	if tex == null:
		return
	# Ícone e texto num bloco centrado dentro do botão (o layout do próprio
	# Button põe o ícone no topo e o texto no pé, com um vão no meio).
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ic := TextureRect.new()
	ic.texture = tex
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = tex.get_size()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)
	var l := Label.new()
	l.text = b.text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FONTE_BOTAO_ICONE)
	# Mesmas cores do texto do botão no tema (ui/principal.gd: _tema).
	var cor := b.get_theme_color("font_color")
	if b.disabled:
		cor = Color(0.64, 0.65, 0.7)
	elif b.toggle_mode and b.button_pressed:
		cor = Color(0.1, 0.1, 0.1)
	l.add_theme_color_override("font_color", cor)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.tooltip_text = b.text
	b.set_meta("rotulo", b.text)
	b.text = ""
	if b.disabled:
		ic.modulate = Color(1, 1, 1, 0.45)
	b.add_child(v)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, tex.get_height() + FONTE_BOTAO_ICONE * 1.4 + 26.0)
	b.custom_minimum_size.x = maxf(b.custom_minimum_size.x,
			ThemeDB.fallback_font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_BOTAO_ICONE).x + 28.0)


static var _reduzidos := {}


## Ícone já no tamanho do botão (largura `tamanho`, altura proporcional): o
## botão calcula a própria altura pelo ícone de 256 px, não pelo limite.
static func icone_reduzido(nome: String, tamanho: int) -> Texture2D:
	var chave := "%s@%d" % [nome, tamanho]
	if not _reduzidos.has(chave):
		var tex := arte(nome)
		if tex == null:
			return null
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var escala := float(tamanho) / maxi(img.get_width(), img.get_height())
		img.resize(maxi(1, roundi(img.get_width() * escala)), maxi(1, roundi(img.get_height() * escala)), Image.INTERPOLATE_LANCZOS)
		_reduzidos[chave] = ImageTexture.create_from_image(img)
	return _reduzidos[chave]


## Botão que executa a ação e reconstrói as telas. `primario` = cor de destaque.
func botao(t: String, acao: Callable, habilitado := true, primario := false, pai: Control = null,
		nome_icone := "") -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 72)
	b.disabled = not habilitado
	if primario and habilitado:
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_DESTAQUE
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(12)
		for estado in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(estado, sb)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color(0.1, 0.1, 0.1))
	com_icone(b, nome_icone)
	b.pressed.connect(func():
		acao.call()
		mudou.emit())
	_pai(pai).add_child(b)
	return b


## Fileira de botões que quebra linha quando não cabe (nunca alarga a tela).
## Os botões dentro dela se esticam para ocupar a linha.
func acoes(pai: Control = null) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 12)
	h.add_theme_constant_override("v_separation", 10)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.child_entered_tree.connect(func(n):
		if n is Button:
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL)
	_pai(pai).add_child(h)
	return h


## Números grandes com a unidade embaixo: [[valor, unidade], ...].
func numeros(lista: Array, pai: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for n in lista:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", -6)
		var a := Label.new()
		a.text = n[0]
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		a.add_theme_font_size_override("font_size", 40)
		v.add_child(a)
		var b := Label.new()
		b.text = n[1]
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", FONTE_PEQUENA)
		b.add_theme_color_override("font_color", COR_SECUNDARIA)
		v.add_child(b)
		h.add_child(v)
	_pai(pai).add_child(h)
	return h


## Botão discreto, só texto (ação secundária).
func botao_texto(t: String, acao: Callable, pai: Control = null, habilitado := true) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.disabled = not habilitado
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", FONTE_PEQUENA + 2)
	b.add_theme_color_override("font_color", COR_INFO.lightened(0.2))
	b.pressed.connect(func():
		acao.call()
		mudou.emit())
	_pai(pai).add_child(b)
	return b


## Commit publicado (versao.txt, gerado pelo workflow do Pages) ou "local".
static func versao() -> String:
	var v := FileAccess.get_file_as_string("res://versao.txt").strip_edges()
	return v if v != "" else "local"


func fileira(pai: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_pai(pai).add_child(h)
	return h


## Barra de atributo: rótulo, preenchimento até valor/maximo e o número.
## `antes` >= 0 mostra a diferença (verde se melhora, vermelho se piora);
## `menor_melhor` inverte as cores (peso).
func barra(nome: String, valor: float, maximo: float, texto_valor: String, cor: Color,
		pai: Control = null, antes := -1.0, menor_melhor := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 40)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.draw.connect(func():
		var fonte := c.get_theme_default_font()
		var y := c.size.y * 0.5 + FONTE_PEQUENA * 0.35
		c.draw_string(fonte, Vector2(0, y), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE_PEQUENA, COR_SECUNDARIA)
		var x0 := 150.0
		var largura := c.size.x - x0 - 170.0
		var trilho := Rect2(x0, c.size.y * 0.5 - 7, largura, 14)
		c.draw_rect(trilho, Color(0.25, 0.27, 0.32))
		var f := clampf(valor / maxf(maximo, 1e-6), 0.0, 1.0)
		if antes >= 0.0 and not is_equal_approx(antes, valor):
			var fa := clampf(antes / maxf(maximo, 1e-6), 0.0, 1.0)
			var melhora := (valor > antes) != menor_melhor
			c.draw_rect(Rect2(x0, trilho.position.y, largura * minf(f, fa), 14), cor)
			c.draw_rect(Rect2(x0 + largura * minf(f, fa), trilho.position.y, largura * absf(f - fa), 14),
					COR_BOM if melhora else COR_RUIM)
		else:
			c.draw_rect(Rect2(x0, trilho.position.y, largura * f, 14), cor)
		c.draw_string(fonte, Vector2(c.size.x - 160.0, y), texto_valor, HORIZONTAL_ALIGNMENT_RIGHT, 160.0,
				FONTE_PEQUENA, Color.WHITE))
	_pai(pai).add_child(c)
	return c


## Potência e peso do carro em barras, relativos ao catálogo.
func barras_carro(a: Dictionary, pai: Control = null, antes: Dictionary = {}) -> void:
	var max_cv := 1.0
	var max_kg := 1.0
	for c in dados.lista("carros"):
		max_cv = maxf(max_cv, float(c["potencia"]))
		max_kg = maxf(max_kg, float(c["peso"]))
	barra("Potência", a["potencia"], max_cv * 1.4, "%d cv" % a["potencia"], COR_DESTAQUE, pai,
			antes.get("potencia", -1.0))
	barra("Peso", a["peso"], max_kg * 1.2, "%d kg" % a["peso"], COR_INFO, pai, antes.get("peso", -1.0), true)


func separador(pai: Control = null) -> void:
	_pai(pai).add_child(HSeparator.new())


func _pai(pai: Control) -> Control:
	return pai if pai != null else conteudo


# --- Compatibilidade com as telas antigas ----------------------------------

func titulo(t: String) -> Label:
	return rotulo(t, 36)


func texto(t: String, cor := Color.WHITE) -> Label:
	return rotulo(t, 0, cor)


## Linha com descrição à esquerda e botões à direita. botoes: [[rótulo, Callable, habilitado]].
## `icone` (placeholder de carro ou pista, ver Icones) vai antes do texto.
func linha(descricao: String, botoes: Array = [], icone: Control = null, pai: Control = null) -> HBoxContainer:
	var h := fileira(pai)
	if icone != null:
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(icone)
	if descricao != "":
		rotulo(descricao, 0, Color.WHITE, h)
	else:
		var espaco := Control.new()
		espaco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(espaco)
	for b in botoes:
		botao(b[0], b[1], b.size() <= 2 or b[2], b.size() > 3 and b[3], h)
	return h


# --- Placeholders e formatação ---------------------------------------------

## Foto do modelo: o sprite isométrico (decisão 31) ou, sem ele, o Estudio.
func icone_carro(base: Dictionary, grande := false, cor := Color(0, 0, 0, 0)) -> Control:
	return Estudio.imagem(base, cor if cor.a > 0.0 else Cores.fabrica(String(base.get("id", ""))),
			Vector2(200, 110) if grande else Vector2(140, 78))


## Amostras das cores do modelo; tocar troca a vitrine e a cor da compra.
func _amostras_cor(base: Dictionary, vit: VitrineCarro, pai: Control) -> void:
	var chaves := Cores.chaves(String(base["id"]))
	if chaves.size() < 2:
		return
	var nome := rotulo(Cores.nome(chaves[0]), FONTE_PEQUENA + 2, COR_SECUNDARIA, pai)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var fila := HFlowContainer.new()
	fila.alignment = FlowContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("h_separation", 12)
	fila.add_theme_constant_override("v_separation", 12)
	pai.add_child(fila)
	var botoes := []
	for k in chaves.size():
		var cor := Cores.cor(chaves[k])
		var b := Button.new()
		b.custom_minimum_size = Vector2(68, 68)
		b.tooltip_text = Cores.nome(chaves[k])
		botoes.append(b)
		fila.add_child(b)
		b.pressed.connect(func():
			cor_escolhida = cor.to_html(false)
			nome.text = Cores.nome(chaves[k])
			vit.mostrar_modelo(base, cor)
			for i in botoes.size():
				_estilo_amostra(botoes[i], Cores.cor(chaves[i]), i == k))
		_estilo_amostra(b, cor, k == 0)


static func _estilo_amostra(b: Button, cor: Color, marcada: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(34)
	sb.set_border_width_all(5 if marcada else 2)
	sb.border_color = COR_DESTAQUE if marcada else Color(1, 1, 1, 0.35)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado, sb)


## Pistas montadas uma vez por id (o traçado não muda durante o jogo).
var _pistas_cache := {}


func icone_pista(pista_id: String) -> Control:
	if not _pistas_cache.has(pista_id):
		_pistas_cache[pista_id] = dados.pista(pista_id)
	return Icones.pista(_pistas_cache[pista_id])


func carro_ativo() -> Carro:
	return jogador.garagem.carro(jogador.carro_ativo)


static func dinheiro(valor: int) -> String:
	var s := str(absi(valor))
	var r := ""
	while s.length() > 3:
		r = "." + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return ("-" if valor < 0 else "") + s + r


func ficha(c: Carro, condicao := "seco") -> String:
	var a := c.atributos_efetivos(condicao)
	var t := "%s · %s · %d cv · %d kg" % [c.base["nome"], c.base["tracao"], a["potencia"], a["peso"]]
	if a["velocidade_max"] != INF:
		t += " · %d km/h" % a["velocidade_max"]
	return t


const NOMES_CATEGORIA_CARRO := {"compacto": "Compacto", "seda": "Sedã", "cupe": "Cupê", "roadster": "Roadster"}
## Ícone e nome curto de cada tração (público geral: sem sigla).
const ICONE_TRACAO := {"FF": "icone_tracao_dianteira", "FR": "icone_tracao_traseira", "MR": "icone_tracao_central",
	"RR": "icone_tracao_traseira", "4WD": "icone_tracao_4x4"}
const NOMES_TRACAO_CURTO := {"FF": "Tração dianteira", "FR": "Tração traseira", "MR": "Motor central",
	"RR": "Motor traseiro", "4WD": "Tração 4x4"}
const NOMES_TRACAO := {
	"FF": "Dianteira (FF)", "FR": "Traseira (FR)", "MR": "Motor central (MR)",
	"RR": "Motor traseiro (RR)", "4WD": "Integral (4WD)",
}


## Selos de tração e categoria de um carro.
func selos_carro(base: Dictionary) -> Array:
	return [
		[NOMES_TRACAO.get(base["tracao"], base["tracao"]), COR_NEUTRA.lightened(0.3)],
		[NOMES_CATEGORIA_CARRO.get(base.get("categoria", ""), base.get("categoria", "")), COR_NEUTRA.lightened(0.3)],
	]


## Nomes que não saem do id.
## Os ids são internos; o nome de cada pista é este (todas originais).
const NOMES_PISTA := {"anel_do_vale": "Lago Sereno", "anel_curto": "Lago Sereno (curto)",
	"parque_das_docas": "Cais Velho", "docas_curta": "Cais Velho (curto)",
	"serra_alta": "Alto da Capela", "serra_curta": "Alto da Capela (curto)",
	"pista_de_testes": "Oval do Planalto", "circuito_misto": "Colinas do Vinhedo"}


## Nome da prova para a tela: "Copa Primeira Marcha — Etapa 1" (nos dados a
## etapa vem em minúscula, que é a chave dos campeonatos).
static func nome_evento(ev: Dictionary) -> String:
	return String(ev.get("nome", "")).replace(" — etapa ", " — Etapa ")


## Nome legível de uma pista (NOMES_PISTA; sem entrada, sai do id).
static func nome_pista(id: String) -> String:
	if NOMES_PISTA.has(id):
		return NOMES_PISTA[id]
	var palavras := []
	for p in id.split("_"):
		palavras.append(p if p in ["do", "da", "das", "de", "dos"] else p.capitalize())
	return " ".join(palavras)


## Teste de preparação: compara duas preparações do carro na prova, sem
## prêmio e sem contar dia (Mecanico.avaliar, mesmas sementes para as duas).
## Opções: a atual, as salvas e a de fábrica. "Equipar" troca no carro.
func testar_preparacao(evento_id: String, carro: Carro) -> void:
	var opcoes := [["Como está agora", carro.configuracao()]]
	for cfg in carro.configuracoes:
		opcoes.append([cfg["nome"], cfg])
	opcoes.append(["De fábrica", {"pecas": [], "ajuste_cambio": ""}])
	var escolhas := [0, 1 if opcoes.size() > 1 else 0]
	painel.emit("Comparar montagens", func(v):
		nota("icone_comparar", "%s · %s" % [nome_curto(carro.base["nome"]), dados.evento(evento_id)["nome"]],
				"", v)
		rotulo("Só compara: sem prêmio, %d corridas cada." % Mecanico.amostras_para(dados.evento(evento_id)), FONTE_PEQUENA, COR_SECUNDARIA, v)
		var resultado := VBoxContainer.new()
		for k in 2:
			var h := fileira(v)
			rotulo("AB"[k], 30, COR_DESTAQUE, h).size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var o := OptionButton.new()
			o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			o.custom_minimum_size = Vector2(0, 60)
			for op in opcoes:
				o.add_item(op[0])
			o.select(escolhas[k])
			o.item_selected.connect(func(i): escolhas[k] = i)
			h.add_child(o)
		var comparar := botao("Comparar", func(): pass, true, true, v)
		v.add_child(resultado)
		comparar.pressed.connect(func():
			for x in resultado.get_children():
				x.queue_free()
			rotulo("Comparando…", FONTE_PEQUENA + 2, COR_INFO, resultado)
			await get_tree().process_frame
			await get_tree().process_frame
			for x in resultado.get_children():
				x.queue_free()
			var medias := []
			for k in 2:
				var op: Array = opcoes[escolhas[k]]
				var montado := carro.com_configuracao(op[1], dados.peca)
				var a := Mecanico.avaliar(jogador.carreira, evento_id, carro.uid, montado)
				var at := montado.atributos_efetivos(dados.evento(evento_id)["condicao"])
				if a.is_empty():
					medias.append(INF)
					rotulo("%s · %s: não pode correr esta corrida." % ["AB"[k], op[0]], FONTE_PEQUENA + 2, COR_RUIM, resultado)
				else:
					medias.append(a["media"])
					rotulo("%s · %s: %s (média %.1fº) · %d cv · %d kg" % ["AB"[k], op[0], Mecanico.texto_faixa(a["faixa"]),
							a["media"], at["potencia"], at["peso"]], FONTE_PEQUENA + 2, Color.WHITE, resultado)
			var cond: String = dados.evento(evento_id)["condicao"]
			var aa := carro.com_configuracao(opcoes[escolhas[0]][1], dados.peca).atributos_efetivos(cond)
			var ab := carro.com_configuracao(opcoes[escolhas[1]][1], dados.peca).atributos_efetivos(cond)
			if GraficoMotor.tem_curva(aa):
				resultado.add_child(GraficoMotor.new([{"rotulo": "A", "cor": COR_SECUNDARIA, "attrs": aa},
						{"rotulo": "B", "cor": COR_DESTAQUE, "attrs": ab}], 170.0))
			var melhor := -1
			if absf(medias[0] - medias[1]) >= Mecanico.GANHO_MINIMO:
				melhor = 0 if medias[0] < medias[1] else 1
			if melhor < 0:
				rotulo("Diferença pequena demais para separar as duas.", FONTE_PEQUENA + 2, COR_SECUNDARIA, resultado)
				return
			var op_m: Array = opcoes[escolhas[melhor]]
			rotulo("Melhor aqui: %s." % op_m[0], FONTE_PEQUENA + 3, COR_BOM, resultado)
			if op_m[1]["pecas"] != carro.configuracao()["pecas"] or op_m[1].get("ajuste_cambio", "") != carro.ajuste_cambio:
				botao("Usar %s" % op_m[0], func():
					var fora: Array = carro.equipar(op_m[1], dados.peca)
					avisar("Em uso: %s%s." % [op_m[0], "" if fora.is_empty() else " (sem %d peça%s não compradas)" % [
							fora.size(), "" if fora.size() == 1 else "s"]], fora.is_empty())
					mudou.emit(), true, false, resultado)))
