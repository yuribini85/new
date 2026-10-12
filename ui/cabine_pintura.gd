class_name CabinePintura
extends Control
## Cabine de pintura (proposta do usuário, Chrome_Wreckage_Sugestao_Cabine_Pintura):
## tela cheia com o carro real em 3D fixo em cima (gira e sobe com o dedo,
## pinça aproxima, vistas 3/4, lateral, traseira e topo da mesma câmera), as
## abas CORES, FAIXAS, IDENTIDADE e ACABAMENTO (só a ativa aparece e só ela
## rola) e as ações sempre visíveis: DESFAZER (volta ao que estava ao abrir),
## CANCELAR e APLICAR PINTURA. Nada é gravado antes de Aplicar; o preço é o de
## PinturaCarro (só o que mudou). A prévia só troca parâmetros do shader
## (CarroBloco.repintar); as miniaturas das faixas são renders do próprio
## carro com cada desenho, não figuras.

signal aplicada
signal fechada
signal aviso(texto: String, ok: bool)

const ABAS := [["cores", "Cores"], ["faixas", "Faixas"], ["identidade", "Identidade"], ["acabamento", "Acabamento"]]
const CANAIS := [["cor", "Carroceria"], ["faixa", "Faixa"], ["filete", "Filete"]]
const CANAIS_NUMERO := [["cor_numero", "Número"], ["cor_contorno", "Contorno"]]
const ALTURA_PREVIA_FRAC := 0.36
const ALTURA_PREVIA_MIN := 300.0
const MINIATURA := Vector2(200, 130)
const COLUNAS_FAIXAS := 3
const AMOSTRA := 58.0

var _dados: Node
var _jogador: Node
var _carro: Carro
## Estado em edição e o de quando a cabine abriu (DESFAZER volta a ele).
var _estado := {}
var _inicio := {}
var _aba := "cores"
var _canal := "cor"
var _canal_numero := "cor_numero"

var _previa: VitrineCarro
var _gerador: VitrineCarro
var _conteudo: VBoxContainer
var _botoes_aba := {}
var _preco: Label
var _aplicar: Button
var _desfazer: Button
## padrão -> ImageTexture; refeitas quando as cores mudam.
var _miniaturas := {}
var _cores_miniaturas := ""
var _gerando := false
var _fechando := false


func _init(dados: Node, jogador: Node, carro: Carro) -> void:
	_dados = dados
	_jogador = jogador
	_carro = carro
	var f := PinturaCarro.normalizar(carro.faixas)
	_estado = {"cor": "#" + CarroBloco.cor_do_carro(carro).to_html(false),
			"padrao": String(f.get("padrao", "")), "faixa": String(f.get("faixa", "#f2f2ee")),
			"filete": String(f.get("filete", "#1c1c1e")), "numero": int(f.get("numero", -1)),
			"locais_numero": int(f.get("locais_numero", PinturaCarro.LOCAIS_PADRAO)),
			"cor_numero": String(f.get("cor_numero", "#141518")), "cor_contorno": String(f.get("cor_contorno", "#f2f2ee")),
			"acabamento": String(f.get("acabamento", ""))}
	_inicio = _estado.duplicate()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Aba.COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	v.add_child(_cabecalho())
	v.add_child(_montar_previa())
	v.add_child(_abas())
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rolagem)
	var margem := MarginContainer.new()
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(k, Aba.MARGEM_LATERAL)
	margem.add_theme_constant_override("margin_top", 14)
	margem.add_theme_constant_override("margin_bottom", 14)
	rolagem.add_child(margem)
	_conteudo = VBoxContainer.new()
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_conteudo.add_theme_constant_override("separation", 12)
	margem.add_child(_conteudo)
	v.add_child(_rodape())
	# Gerador das miniaturas: uma vitrine fora da tela, no ângulo 3/4 de cima.
	_gerador = VitrineCarro.new(MINIATURA.y)
	_gerador.custom_minimum_size = MINIATURA
	_gerador.size = MINIATURA
	_gerador.position = Vector2(-4000, 0)
	_gerador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gerador)


func _ready() -> void:
	_previa.ambiente_garagem()
	_previa.mostrar_modelo(_carro.base, Color(_estado["cor"]), _faixas())
	_previa.vista("3/4")
	_gerador.ambiente_garagem()
	_gerador.mostrar_modelo(_carro.base, Color(_estado["cor"]), {})
	_gerador.vista("3/4")
	_gerador._elevacao = 40.0
	_gerador._posicionar_camera()
	resized.connect(_ajustar_previa)
	_ajustar_previa()
	_mostrar_aba()


func _ajustar_previa() -> void:
	_previa.custom_minimum_size.y = maxf(size.y * ALTURA_PREVIA_FRAC, ALTURA_PREVIA_MIN)


## O que vai para Carro.faixas (sem o que está no padrão de fábrica).
func _faixas() -> Dictionary:
	return PinturaCarro.normalizar(_estado)


func _cabecalho() -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size.y = 84
	h.add_theme_constant_override("separation", 12)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(m)
	var t := Label.new()
	t.text = "PINTURA"
	Tipografia.rotulo(t, "semibold", 46)
	t.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m.add_child(t)
	var x := Button.new()
	x.text = "×"
	x.flat = true
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(84, 84)
	Tipografia.rotulo(x, "medium", 52)
	x.pressed.connect(_fechar)
	h.add_child(x)
	return h


func _montar_previa() -> Control:
	_previa = VitrineCarro.new(ALTURA_PREVIA_MIN)
	_previa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# As vistas embaixo da prévia: todas da mesma câmera e da mesma pintura.
	var vistas := HBoxContainer.new()
	vistas.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	vistas.offset_left = 12
	vistas.offset_right = -12
	vistas.offset_top = -64
	vistas.offset_bottom = -10
	vistas.add_theme_constant_override("separation", 8)
	vistas.alignment = BoxContainer.ALIGNMENT_CENTER
	_previa.add_child(vistas)
	for par in [["3/4", "3/4"], ["lateral", "Lateral"], ["traseira", "Traseira"], ["topo", "Topo"]]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		Tipografia.acao_neutra(b, par[1], 20, 50)
		b.custom_minimum_size.x = 120
		var nome: String = par[0]
		b.pressed.connect(func(): _previa.vista(nome))
		vistas.add_child(b)
	return _previa


func _abas() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 10)
	m.add_theme_constant_override("margin_top", 10)
	m.add_child(h)
	for par in ABAS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = par[0]
		b.pressed.connect(func():
			_aba = id
			_mostrar_aba())
		h.add_child(b)
		_botoes_aba[id] = [b, String(par[1])]
	return m


func _rodape() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.07)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.border_width_top = 1
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	_preco = Label.new()
	_preco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preco.add_theme_font_size_override("font_size", Aba.FONTE_PEQUENA)
	_preco.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	v.add_child(_preco)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	_desfazer = Button.new()
	Tipografia.acao_neutra(_desfazer, "Desfazer", 24, 72)
	_desfazer.tooltip_text = "Volta à pintura de quando a cabine abriu"
	_desfazer.custom_minimum_size.x = 150
	_desfazer.pressed.connect(func():
		_estado = _inicio.duplicate()
		_mudou())
	h.add_child(_desfazer)
	var cancelar := Button.new()
	Tipografia.acao_neutra(cancelar, "Cancelar", 24, 72)
	cancelar.custom_minimum_size.x = 150
	cancelar.pressed.connect(_fechar)
	h.add_child(cancelar)
	_aplicar = Button.new()
	Tipografia.acao_primaria(_aplicar, "Aplicar pintura", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26, 72)
	_aplicar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aplicar.pressed.connect(_confirmar)
	h.add_child(_aplicar)
	return p


# ---------------------------------------------------------------- abas

func _mostrar_aba() -> void:
	for id in _botoes_aba:
		var b: Button = _botoes_aba[id][0]
		if id == _aba:
			Tipografia.acao_primaria(b, _botoes_aba[id][1], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 21, 58)
		else:
			Tipografia.acao_neutra(b, _botoes_aba[id][1], 21, 58)
	for c in _conteudo.get_children():
		_conteudo.remove_child(c)
		c.queue_free()
	match _aba:
		"cores":
			_aba_cores()
		"faixas":
			_aba_faixas()
		"identidade":
			_aba_identidade()
		"acabamento":
			_aba_acabamento()
	_atualizar_rodape()


func _titulo(texto: String) -> void:
	var l := Label.new()
	l.text = texto.to_upper()
	Tipografia.rotulo(l, "semibold", 26)
	l.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	_conteudo.add_child(l)


func _nota(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", Aba.FONTE_PEQUENA)
	l.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	_conteudo.add_child(l)


## Seletor de canal: cada um com a amostra da cor atual; o ativo em ocre.
func _canais(lista: Array, ativo: String, habilitado: Callable, ao_escolher: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_conteudo.add_child(h)
	for par in lista:
		var id: String = par[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == ativo:
			Tipografia.acao_primaria(b, par[1], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 22, 64)
		else:
			Tipografia.acao_neutra(b, par[1], 22, 64)
		b.disabled = not habilitado.call(id)
		b.icon = _amostra_icone(Color(_estado[id]))
		b.pressed.connect(func(): ao_escolher.call(id))
		h.add_child(b)


static func _amostra_icone(cor: Color) -> Texture2D:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d <= 13.5:
				img.set_pixel(x, y, Color(1, 1, 1, 0.6) if d > 11.5 else cor)
	return ImageTexture.create_from_image(img)


## A paleta da pintura para o canal `chave`.
func _paleta(chave: String) -> void:
	var g := GridContainer.new()
	g.columns = 9
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_conteudo.add_child(g)
	for it in PinturaCarro.cores():
		var a := Button.new()
		a.focus_mode = Control.FOCUS_NONE
		a.tooltip_text = String(it["nome"])
		a.custom_minimum_size = Vector2(AMOSTRA, AMOSTRA)
		var cor: Color = it["cor"]
		Aba._estilo_amostra(a, cor, cor.to_html(false) == Color(_estado[chave]).to_html(false))
		var hex := "#" + cor.to_html(false)
		a.pressed.connect(func():
			_estado[chave] = hex
			_mudou())
		g.add_child(a)


func _aba_cores() -> void:
	var com_faixa: bool = _estado["padrao"] != ""
	if not com_faixa and _canal != "cor":
		_canal = "cor"
	_titulo("Cor de")
	_canais(CANAIS, _canal, func(id): return id == "cor" or com_faixa, func(id):
		_canal = id
		_mostrar_aba())
	if not com_faixa:
		_nota("Faixa e filete valem quando há um desenho: escolha um em FAIXAS.")
	_paleta(_canal)


func _aba_faixas() -> void:
	_titulo("Desenho")
	var g := GridContainer.new()
	g.columns = COLUNAS_FAIXAS
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	_conteudo.add_child(g)
	for pd in PinturaCarro.PADROES:
		var id := String(pd[0])
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = MINIATURA.y + 46
		var marcado: bool = id == _estado["padrao"]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Aba.COR_CARTAO
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(3 if marcado else 1)
		sb.border_color = Aba.COR_DESTAQUE if marcado else Color(1, 1, 1, 0.1)
		for e in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(e, sb)
		b.pressed.connect(func():
			_estado["padrao"] = id
			_mudou())
		g.add_child(b)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 4
		v.offset_right = -4
		v.offset_top = 4
		v.offset_bottom = -4
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(0, MINIATURA.y)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.texture = _miniaturas.get(id)
		img.set_meta("padrao", id)
		v.add_child(img)
		var l := Label.new()
		l.text = String(pd[1]).to_upper()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		Tipografia.rotulo(l, "semibold", 20)
		l.add_theme_color_override("font_color", Aba.COR_DESTAQUE if marcado else Color(0.86, 0.87, 0.9))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	_gerar_miniaturas()


func _aba_identidade() -> void:
	_titulo("Número de corrida")
	var tem: bool = int(_estado["numero"]) >= 0
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_conteudo.add_child(h)
	var sem := Button.new()
	sem.focus_mode = Control.FOCUS_NONE
	if tem:
		Tipografia.acao_neutra(sem, "Sem número", 22, 64)
	else:
		Tipografia.acao_primaria(sem, "Sem número", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 22, 64)
	sem.custom_minimum_size.x = 170
	sem.pressed.connect(func():
		_estado["numero"] = -1 if tem else 1
		_mudou())
	h.add_child(sem)
	for passo in [-10, -1]:
		h.add_child(_passo_numero(passo, tem))
	var n := Label.new()
	n.text = str(int(_estado["numero"])) if tem else "—"
	n.custom_minimum_size.x = 96
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Tipografia.numero(n, 48)
	h.add_child(n)
	for passo in [1, 10]:
		h.add_child(_passo_numero(passo, tem))
	if not tem:
		_nota("Toque em Sem número para ligar o número.")
		return
	_titulo("Onde")
	var locais := HBoxContainer.new()
	locais.add_theme_constant_override("separation", 8)
	_conteudo.add_child(locais)
	var mascara: int = int(_estado["locais_numero"])
	for par in PinturaCarro.LOCAIS:
		var bit: int = par[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mascara & bit:
			Tipografia.acao_primaria(b, par[1], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 22, 60)
		else:
			Tipografia.acao_neutra(b, par[1], 22, 60)
		b.pressed.connect(func():
			var nova: int = mascara ^ bit
			if nova != 0:  # ao menos um lugar
				_estado["locais_numero"] = nova
				_mudou())
		locais.add_child(b)
	_titulo("Cor de")
	_canais(CANAIS_NUMERO, _canal_numero, func(_id): return true, func(id):
		_canal_numero = id
		_mostrar_aba())
	_paleta(_canal_numero)


func _passo_numero(passo: int, tem: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	Tipografia.acao_neutra(b, "%+d" % passo, 22, 64)
	b.custom_minimum_size.x = 76
	b.disabled = not tem
	b.pressed.connect(func():
		_estado["numero"] = clampi(int(_estado["numero"]) + passo, 0, PinturaCarro.NUMERO_MAX)
		_mudou())
	return b


func _aba_acabamento() -> void:
	_titulo("Acabamento da lataria")
	const TEXTOS := {"fosco": "Sem brilho, cor chapada.", "": "Brilho discreto: o de fábrica.",
			"brilhante": "Verniz: reflexo forte e cor viva.", "metalico": "Brilho metálico que muda com a luz."}
	for par in PinturaCarro.ACABAMENTOS:
		var id: String = par[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var marcado: bool = id == _estado["acabamento"]
		if marcado:
			Tipografia.acao_primaria(b, "%s   ·   %s" % [par[1], TEXTOS[id]], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 22, 70)
		else:
			Tipografia.acao_neutra(b, "%s   ·   %s" % [par[1], TEXTOS[id]], 22, 70)
		b.pressed.connect(func():
			_estado["acabamento"] = id
			_mudou())
		_conteudo.add_child(b)


# ---------------------------------------------------------------- estado

## Algo mudou: a prévia troca na hora; a aba e o rodapé são refeitos.
func _mudou() -> void:
	_previa.repintar(Color(_estado["cor"]), _faixas())
	_mostrar_aba()


func _muda_cor() -> bool:
	return Color(_estado["cor"]).to_html(false) != CarroBloco.cor_do_carro(_carro).to_html(false)


func _muda_faixas() -> bool:
	return _faixas() != PinturaCarro.normalizar(_carro.faixas)


func _atualizar_rodape() -> void:
	var mc := _muda_cor()
	var mf := _muda_faixas()
	var preco := PinturaCarro.preco(_dados, _jogador, mc, mf)
	if not mc and not mf:
		_preco.text = "Nada mudou ainda."
	elif not PinturaCarro.preco_definido(_dados):
		_preco.text = "Preço a definir (grátis por enquanto)."
	else:
		_preco.text = "Custa %s giros." % Aba.dinheiro(preco)
	_aplicar.disabled = (not mc and not mf) or not _jogador.economia.pode_pagar(preco)
	_desfazer.disabled = _estado == _inicio


func _confirmar() -> void:
	var motivo := PinturaCarro.aplicar(_dados, _jogador, _carro, _estado["cor"], _faixas())
	if motivo != "":
		aviso.emit("Não deu: %s." % motivo, false)
		return
	Sons.tocar_ui(self, "moeda", -4.0)
	aplicada.emit()
	_fechar()


func _fechar() -> void:
	fechada.emit()
	# Com miniatura sendo feita, sai da tela já e se solta quando ela terminar
	# (a corrotina não pode voltar a uma cabine liberada).
	_fechando = true
	visible = false
	if not _gerando:
		queue_free()


# ---------------------------------------------------------------- miniaturas

## Cada desenho renderizado no próprio carro, nas cores escolhidas (um por
## quadro, para não travar a tela); refeitas só quando as cores mudam.
func _gerar_miniaturas() -> void:
	var chave := "%s|%s|%s" % [_estado["cor"], _estado["faixa"], _estado["filete"]]
	if chave != _cores_miniaturas:
		_cores_miniaturas = chave
		_miniaturas.clear()
	if _gerando:
		return
	_gerando = true
	for pd in PinturaCarro.PADROES:
		var id := String(pd[0])
		if _miniaturas.has(id):
			continue
		if _fechando or not is_inside_tree():
			break
		var f := {} if id == "" else {"padrao": id, "faixa": _estado["faixa"], "filete": _estado["filete"]}
		_gerador.repintar(Color(_estado["cor"]), f)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if _fechando or not is_inside_tree() or chave != _cores_miniaturas:
			break
		_miniaturas[id] = ImageTexture.create_from_image(_gerador.imagem())
		for tr in _conteudo.find_children("*", "TextureRect", true, false):
			if tr.get_meta("padrao", null) == id:
				tr.texture = _miniaturas[id]
	_gerando = false
	if _fechando:
		queue_free()
		return
	if is_inside_tree() and _aba == "faixas" and _miniaturas.size() < PinturaCarro.PADROES.size():
		_gerar_miniaturas()
