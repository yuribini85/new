class_name CabinePintura
extends Control
## Cabine de pintura (propostas do usuário: Sugestão de Cabine de Pintura e
## Identidades das Equipes): tela cheia com o carro real em 3D fixo em cima
## (gira e sobe com o dedo, pinça aproxima, vistas 3/4, lateral, traseira e
## topo da mesma câmera), quatro abas (só a ativa aparece e só ela rola):
## PINTURA (cores base, secundária e acento; largura e espelho do desenho),
## GRAFISMOS (os desenhos, em miniaturas renderizadas no próprio carro),
## IDENTIFICAÇÃO (nome e logo da equipe, independentes; onde o logo vai; o
## número de corrida com família, tamanho, suporte, lugares e cores) e
## ACABAMENTO (fosco a metálico; poeira e arranhões numa camada à parte) e
## RODAS (o aro do carro, do catálogo Rodas; não custa; só nos carros do
## gerado, Carroceria.ativos). Em
## baixo, sempre: desfazer/refazer passo a passo, COMO ESTAVA (o que havia ao
## abrir), CANCELAR e APLICAR. Nada é gravado antes de Aplicar; o preço é o de
## PinturaCarro (só o que mudou no carro; nome e logo da equipe não custam).

signal aplicada
signal fechada
signal aviso(texto: String, ok: bool)

const ABAS := [["pintura", "Pintura"], ["grafismos", "Grafismos"], ["identificacao", "Identificação"],
		["acabamento", "Acabamento"], ["rodas", "Rodas"]]
const COLUNAS_RODAS := 2
const ALTURA_RODA := 88.0  # área de toque de cada aro
const CANAIS := [["cor", "Base"], ["faixa", "Secundária"], ["filete", "Acento"]]
const CANAIS_NUMERO := [["cor_numero", "Número"], ["cor_contorno", "Contorno"]]
const ALTURA_PREVIA_FRAC := 0.34
const ALTURA_PREVIA_MIN := 280.0
const MINIATURA := Vector2(200, 130)
const COLUNAS_FAIXAS := 3
const COLUNAS_LOGOS := 5
const AMOSTRA := 58.0
const HISTORICO_MAX := 40

var _dados: Node
var _jogador: Node
var _carro: Carro
## Estado em edição e o de quando a cabine abriu (COMO ESTAVA volta a ele).
var _estado := {}
var _inicio := {}
var _antes: Array = []  # desfazer
var _depois: Array = []  # refazer
var _aba := "pintura"
var _canal := "cor"
var _canal_numero := "cor_numero"

var _previa: VitrineCarro
var _gerador: VitrineCarro
var _conteudo: VBoxContainer
var _botoes_aba := {}
var _preco: Label
var _aplicar: Button
var _como_estava: Button
var _voltar: Button
var _avancar: Button
## desenho -> ImageTexture; refeitas quando as cores mudam.
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
			"filete": String(f.get("filete", "#1c1c1e")), "largura": float(f.get("largura", 1.0)),
			"espelhar": bool(f.get("espelhar", false)),
			"numero": int(f.get("numero", -1)),
			"locais_numero": int(f.get("locais_numero", PinturaCarro.LOCAIS_PADRAO)),
			"cor_numero": String(f.get("cor_numero", "#141518")), "cor_contorno": String(f.get("cor_contorno", "#f2f2ee")),
			"fonte_numero": String(f.get("fonte_numero", "condensado")),
			"escala_numero": float(f.get("escala_numero", 1.0)), "suporte_numero": bool(f.get("suporte_numero", false)),
			"locais_logo": int(f.get("locais_logo", 0)), "escala_logo": float(f.get("escala_logo", 1.0)),
			"acabamento": String(f.get("acabamento", "")),
			"poeira": float(f.get("poeira", 0.0)), "arranhoes": float(f.get("arranhoes", 0.0)),
			"roda": Rodas.desenho_de(f),
			"equipe_nome": String(jogador.identidade.get("nome", "")), "equipe_logo": IdentidadeEquipe.logo(jogador), "apelido": carro.apelido}
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
	_previa.mostrar_modelo(_carro.base, Color(_estado["cor"]), _faixas_previa())
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


## O que vai para Carro.faixas (sem o que é de fábrica; o logo do jogador vem
## da equipe, não fica no carro).
func _faixas() -> Dictionary:
	var f := PinturaCarro.normalizar(_estado)
	f.erase("logo")
	return f


## Para a prévia: com o logo escolhido agora (ainda não gravado na equipe).
func _faixas_previa() -> Dictionary:
	var e := _estado.duplicate()
	e["logo"] = IdentidadeEquipe.arquivo_logo(String(_estado["equipe_logo"]))
	return PinturaCarro.normalizar(e)


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
	vistas.offset_top = -64 - 17
	vistas.offset_bottom = -10 + 17
	vistas.add_theme_constant_override("separation", 8)
	vistas.alignment = BoxContainer.ALIGNMENT_CENTER
	_previa.add_child(vistas)
	for par in [["3/4", "3/4"], ["lateral", "Lateral"], ["traseira", "Traseira"], ["topo", "Topo"]]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		Tipografia.acao_neutra(b, par[1], 20, 50)
		Tipografia.area_toque(b, 50)  # sobre a prévia: o desenho de sempre, o toque maior
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
		# RODAS só nos carros gerados (Carroceria): no GLB o aro não troca.
		if par[0] == "rodas" and not Carroceria.tem(_carro.id):
			continue
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
	sb.content_margin_left = 12
	sb.content_margin_right = 12
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
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	_voltar = _botao_rodape("", 64, h)
	_icone(_voltar, "desfazer")
	_voltar.tooltip_text = "Desfazer o último passo"
	_voltar.pressed.connect(func(): _passo(_antes, _depois))
	_avancar = _botao_rodape("", 64, h)
	_icone(_avancar, "refazer")
	_avancar.tooltip_text = "Refazer"
	_avancar.pressed.connect(func(): _passo(_depois, _antes))
	_como_estava = _botao_rodape("Como estava", 150, h)
	_como_estava.tooltip_text = "Volta à pintura de quando a cabine abriu"
	_como_estava.pressed.connect(func(): _mudar(_inicio.duplicate()))
	var cancelar := _botao_rodape("Cancelar", 124, h)
	cancelar.pressed.connect(_fechar)
	_aplicar = Button.new()
	Tipografia.acao_primaria(_aplicar, "Aplicar", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 26, Tipografia.ALTURA_SECUNDARIA)
	_aplicar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aplicar.pressed.connect(_confirmar)
	h.add_child(_aplicar)
	return p


func _icone(b: Button, tipo: String) -> void:
	var ic := IconeVetor.new(tipo, Color(0.86, 0.87, 0.9))
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 14
	ic.offset_right = -14
	ic.offset_top = 16
	ic.offset_bottom = -16
	b.add_child(ic)


func _botao_rodape(texto: String, largura: float, pai: Control) -> Button:
	var b := Button.new()
	Tipografia.acao_neutra(b, texto, 24 if texto.length() > 2 else 34, 72)
	b.custom_minimum_size.x = largura
	pai.add_child(b)
	return b


# ---------------------------------------------------------------- abas

func _mostrar_aba() -> void:
	for id in _botoes_aba:
		var b: Button = _botoes_aba[id][0]
		if id == _aba:
			Tipografia.acao_primaria(b, _botoes_aba[id][1], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 20, 58)
		else:
			Tipografia.acao_neutra(b, _botoes_aba[id][1], 20, 58)
		Tipografia.area_toque(b, 58)
	for c in _conteudo.get_children():
		_conteudo.remove_child(c)
		c.queue_free()
	match _aba:
		"pintura":
			_aba_pintura()
		"grafismos":
			_aba_grafismos()
		"identificacao":
			_aba_identificacao()
		"acabamento":
			_aba_acabamento()
		"rodas":
			_aba_rodas()
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


## Fileira de escolhas [[valor, rótulo], ...]: a marcada em ocre.
func _escolhas(lista: Array, atual: Variant, ao_escolher: Callable, altura := 60, tamanho := 22) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_conteudo.add_child(h)
	for par in lista:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var marcado: bool = par[0] == atual if not (par[0] is float) else is_equal_approx(float(par[0]), float(atual))
		if marcado:
			Tipografia.acao_primaria(b, par[1], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), tamanho, altura)
		else:
			Tipografia.acao_neutra(b, par[1], tamanho, altura)
		var valor: Variant = par[0]
		b.pressed.connect(func(): ao_escolher.call(valor))
		h.add_child(b)
	return h


## Fileira de interruptores para uma soma de bits [[bit, rótulo], ...].
func _bits(lista: Array, chave: String, minimo_um: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_conteudo.add_child(h)
	var mascara: int = int(_estado[chave])
	for par in lista:
		var bit: int = par[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if mascara & bit:
			Tipografia.acao_primaria(b, par[1], Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 20, 60)
		else:
			Tipografia.acao_neutra(b, par[1], 20, 60)
		b.pressed.connect(func():
			var nova: int = mascara ^ bit
			if nova != 0 or not minimo_um:
				_definir(chave, nova))
		h.add_child(b)


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
		Tipografia.area_toque(b, 64)
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
	# Cada cor desenhada com AMOSTRA, numa área de toque de ALTURA_SECUNDARIA
	# (as áreas se encostam; o vão entre as cores é a sobra delas).
	var g := GridContainer.new()
	g.columns = 7
	g.add_theme_constant_override("h_separation", 0)
	g.add_theme_constant_override("v_separation", 0)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_conteudo.add_child(g)
	for it in PinturaCarro.cores():
		var a := Button.new()
		a.focus_mode = Control.FOCUS_NONE
		a.tooltip_text = String(it["nome"])
		a.custom_minimum_size = Vector2(AMOSTRA, AMOSTRA)
		var cor: Color = it["cor"]
		Aba._estilo_amostra(a, cor, cor.to_html(false) == Color(_estado[chave]).to_html(false))
		Tipografia.area_toque(a, AMOSTRA, AMOSTRA)
		var hex := "#" + cor.to_html(false)
		a.pressed.connect(func(): _definir(chave, hex))
		g.add_child(a)


## Controle deslizante 0..1 (desgaste).
func _deslizante(rotulo: String, chave: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	_conteudo.add_child(h)
	var l := Label.new()
	l.text = rotulo.to_upper()
	l.custom_minimum_size.x = 170
	Tipografia.rotulo(l, "semibold", 22)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(_estado[chave])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size.y = 48
	s.focus_mode = Control.FOCUS_NONE
	# Só ao soltar entra no histórico; arrastando, a prévia acompanha.
	s.value_changed.connect(func(v: float):
		var e := _estado.duplicate()
		e[chave] = v
		_previa.repintar(Color(e["cor"]), _faixas_de(e)))
	s.drag_ended.connect(func(_mudou: bool): _definir(chave, s.value))
	h.add_child(s)


func _faixas_de(e: Dictionary) -> Dictionary:
	var c := e.duplicate()
	c["logo"] = IdentidadeEquipe.arquivo_logo(String(e["equipe_logo"]))
	return PinturaCarro.normalizar(c)


func _aba_pintura() -> void:
	var com_faixa: bool = _estado["padrao"] != ""
	if not com_faixa and _canal != "cor":
		_canal = "cor"
	_titulo("Cores")
	_canais(CANAIS, _canal, func(id): return id == "cor" or com_faixa, func(id):
		_canal = id
		_mostrar_aba())
	if not com_faixa:
		_nota("Secundária e acento pintam o desenho: escolha um em GRAFISMOS.")
	_paleta(_canal)
	if com_faixa:
		_titulo("Largura do desenho")
		_escolhas(PinturaCarro.LARGURAS, float(_estado["largura"]), func(v): _definir("largura", v))
		_titulo("Lado")
		_escolhas([[false, "Normal"], [true, "Espelhado"]], bool(_estado["espelhar"]), func(v): _definir("espelhar", v))


func _aba_grafismos() -> void:
	_titulo("Desenho")
	var g := GridContainer.new()
	g.columns = COLUNAS_FAIXAS
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	_conteudo.add_child(g)
	var n_lib := PinturaCarro.liberados(_dados, _jogador, "padroes", PinturaCarro.PADROES.size())
	for k in PinturaCarro.PADROES.size():
		var pd: Array = PinturaCarro.PADROES[k]
		var id := String(pd[0])
		# Decisão 74: o desenho trancado mostra a posição do Grid que o libera.
		var trancado: bool = k >= n_lib and id != _estado["padrao"]
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
		if trancado:
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.45)
			b.tooltip_text = "Libera na #%d do Grid" % PinturaCarro.posicao_que_libera(_dados, "padroes", k)
		else:
			b.pressed.connect(func(): _definir("padrao", id))
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
		l.text = ("#%d DO GRID" % PinturaCarro.posicao_que_libera(_dados, "padroes", k)) if trancado else String(pd[1]).to_upper()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		Tipografia.rotulo(l, "semibold", 20)
		l.add_theme_color_override("font_color", Aba.COR_DESTAQUE if marcado else Color(0.86, 0.87, 0.9))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	_gerar_miniaturas()


func _aba_identificacao() -> void:
	# Apelido: só deste carro; aparece nos cartões e na Oficina no lugar do nome.
	_titulo("Apelido do carro")
	var ap := LineEdit.new()
	ap.text = String(_estado["apelido"])
	ap.placeholder_text = String(_carro.base["nome"])
	ap.max_length = Carro.APELIDO_MAX
	ap.custom_minimum_size.y = 64
	ap.add_theme_font_size_override("font_size", 26)
	ap.text_submitted.connect(func(t: String): _definir("apelido", t.strip_edges()))
	ap.focus_exited.connect(func():
		if ap.text.strip_edges() != _estado["apelido"]:
			_definir("apelido", ap.text.strip_edges()))
	_conteudo.add_child(ap)
	# Equipe: nome e logo valem para todos os carros e não dependem um do outro.
	_titulo("Equipe")
	var nome := LineEdit.new()
	nome.text = String(_estado["equipe_nome"])
	nome.placeholder_text = IdentidadeEquipe.nome_padrao(_dados, _jogador)
	nome.max_length = IdentidadeEquipe.NOME_MAX
	nome.custom_minimum_size.y = 64
	nome.add_theme_font_size_override("font_size", 26)
	nome.text_submitted.connect(func(t: String):
		_definir("equipe_nome", t.strip_edges()))
	nome.focus_exited.connect(func():
		if nome.text.strip_edges() != _estado["equipe_nome"]:
			_definir("equipe_nome", nome.text.strip_edges()))
	_conteudo.add_child(nome)
	if PinturaCarro.liberados(_dados, _jogador, "logos", IdentidadeEquipe.opcoes().size()) < IdentidadeEquipe.opcoes().size():
		_nota("Cada equipe vencida no Grid libera um logo novo e um desenho novo.")
	var g := GridContainer.new()
	g.columns = COLUNAS_LOGOS
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_conteudo.add_child(g)
	var logos: Array = IdentidadeEquipe.opcoes()
	var n_logos := PinturaCarro.liberados(_dados, _jogador, "logos", logos.size())
	for k in logos.size():
		var o: Dictionary = logos[k]
		var id := String(o["id"])
		var logo_trancado: bool = k >= n_logos and id != _estado["equipe_logo"]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = String(o["nome"])
		b.custom_minimum_size = Vector2(0, 124)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = load(String(o["arquivo"]))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sb := StyleBoxFlat.new()
		sb.bg_color = Aba.COR_CARTAO
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		var marcado: bool = id == _estado["equipe_logo"]
		sb.set_border_width_all(3 if marcado else 1)
		sb.border_color = Aba.COR_DESTAQUE if marcado else Color(1, 1, 1, 0.1)
		for e in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(e, sb)
		if logo_trancado:
			b.disabled = true
			b.modulate = Color(0.35, 0.35, 0.38, 0.6)
			b.tooltip_text = "Libera na #%d do Grid" % PinturaCarro.posicao_que_libera(_dados, "logos", k)
		else:
			b.pressed.connect(func(): _definir("equipe_logo", id))
		g.add_child(b)
	if _estado["equipe_logo"] != "":
		_titulo("Logo no carro")
		_bits(PinturaCarro.LOCAIS_LOGO, "locais_logo", false)
		if int(_estado["numero"]) >= 0 and int(_estado["locais_numero"]) & 2 and int(_estado["locais_logo"]) & 4:
			_nota("O capô já tem o número: lá o logo não vai.")
		_escolhas(PinturaCarro.ESCALAS, float(_estado["escala_logo"]), func(v): _definir("escala_logo", v))
	else:
		_nota("Escolha um logo para o carro.")
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
	sem.pressed.connect(func(): _definir("numero", -1 if tem else 1))
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
		_nota("O carro está sem número. Toque no botão de novo para pôr um.")
		return
	_titulo("Família")
	var fontes := PinturaCarro.FONTES
	_escolhas(fontes.slice(0, 3), _estado["fonte_numero"], func(v): _definir("fonte_numero", v), 56, 20)
	_escolhas(fontes.slice(3), _estado["fonte_numero"], func(v): _definir("fonte_numero", v), 56, 20)
	_titulo("Tamanho e suporte")
	_escolhas(PinturaCarro.ESCALAS, float(_estado["escala_numero"]), func(v): _definir("escala_numero", v))
	_escolhas([[false, "Sem suporte"], [true, "Com círculo"]], bool(_estado["suporte_numero"]),
			func(v): _definir("suporte_numero", v))
	_titulo("Onde")
	_bits(PinturaCarro.LOCAIS, "locais_numero", true)
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
		_definir("numero", clampi(int(_estado["numero"]) + passo, 0, PinturaCarro.NUMERO_MAX)))
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
		var texto := "%s   ·   %s" % [par[1], TEXTOS[id]]
		if id == _estado["acabamento"]:
			Tipografia.acao_primaria(b, texto, Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 22, Tipografia.ALTURA_SECUNDARIA)
		else:
			Tipografia.acao_neutra(b, texto, 22, 70)
		b.pressed.connect(func(): _definir("acabamento", id))
		_conteudo.add_child(b)
	_titulo("Desgaste")
	_nota("Camada à parte, por cima da pintura: tirar volta à cor limpa.")
	_deslizante("Poeira", "poeira")
	_deslizante("Arranhões", "arranhoes")


## O aro das rodas: o mesmo pneu para todos, o desenho do aro à escolha.
func _aba_rodas() -> void:
	_titulo("Aro das rodas")
	_nota("Troca só o aro; o pneu é o mesmo. Não custa.")
	var g := GridContainer.new()
	g.columns = COLUNAS_RODAS
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_conteudo.add_child(g)
	for id in Rodas.DESENHOS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == _estado["roda"]:
			Tipografia.acao_primaria(b, Rodas.nome(id), Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 22, ALTURA_RODA)
		else:
			Tipografia.acao_neutra(b, Rodas.nome(id), 22, ALTURA_RODA)
		Tipografia.area_toque(b, ALTURA_RODA)
		var d: String = id
		b.pressed.connect(func(): _definir("roda", d))
		g.add_child(b)


# ---------------------------------------------------------------- estado

func _definir(chave: String, valor: Variant) -> void:
	if _estado.get(chave) == valor:
		return
	var novo := _estado.duplicate()
	novo[chave] = valor
	_mudar(novo)


## Troca o estado guardando o anterior para desfazer.
func _mudar(novo: Dictionary) -> void:
	if novo == _estado:
		return
	_antes.append(_estado)
	if _antes.size() > HISTORICO_MAX:
		_antes.pop_front()
	_depois.clear()
	_estado = novo
	_mudou()


func _passo(de: Array, para: Array) -> void:
	if de.is_empty():
		return
	para.append(_estado)
	_estado = de.pop_back()
	_mudou()


## Algo mudou: a prévia troca na hora; a aba e o rodapé são refeitos.
func _mudou() -> void:
	_previa.repintar(Color(_estado["cor"]), _faixas_previa())
	_mostrar_aba()


func _muda_cor() -> bool:
	return Color(_estado["cor"]).to_html(false) != CarroBloco.cor_do_carro(_carro).to_html(false)


func _muda_faixas() -> bool:
	var antes := PinturaCarro.sem_roda(_carro.faixas)
	antes.erase("logo")
	var agora := _faixas()
	agora.erase("roda")
	return agora != antes


func _muda_roda() -> bool:
	return String(_estado["roda"]) != Rodas.desenho_de(_carro.faixas)


func _muda_equipe() -> bool:
	return _estado["equipe_nome"] != _inicio["equipe_nome"] or _estado["equipe_logo"] != _inicio["equipe_logo"] \
			or _estado["apelido"] != _inicio["apelido"]


func _atualizar_rodape() -> void:
	var mc := _muda_cor()
	var mf := _muda_faixas()
	var me := _muda_equipe()
	var mr := _muda_roda()
	var preco := PinturaCarro.preco(_dados, _jogador, mc, mf)
	if not mc and not mf and not me and not mr:
		_preco.text = "Nada mudou ainda."
	elif not mc and not mf:
		_preco.text = "Rodas, apelido, nome e logo da equipe não custam."
	elif not PinturaCarro.preco_definido(_dados):
		_preco.text = "Grátis."
	else:
		_preco.text = "Custa %s giros." % Aba.dinheiro(preco)
	_aplicar.disabled = (not mc and not mf and not me and not mr) or not _jogador.economia.pode_pagar(preco)
	_como_estava.disabled = _estado == _inicio
	_voltar.disabled = _antes.is_empty()
	_avancar.disabled = _depois.is_empty()


func _confirmar() -> void:
	if _muda_cor() or _muda_faixas() or _muda_roda():
		var motivo := PinturaCarro.aplicar(_dados, _jogador, _carro, _estado["cor"], _faixas())
		if motivo != "":
			aviso.emit("Não deu: %s." % motivo, false)
			return
	if _muda_equipe():
		IdentidadeEquipe.definir(_jogador, String(_estado["equipe_nome"]), String(_estado["equipe_logo"]))
		_carro.apelido = String(_estado["apelido"]).left(Carro.APELIDO_MAX)
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
	var chave := "%s|%s|%s|%s|%s" % [_estado["cor"], _estado["faixa"], _estado["filete"], _estado["largura"],
			_estado["espelhar"]]
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
		var f := {} if id == "" else {"padrao": id, "faixa": _estado["faixa"], "filete": _estado["filete"],
				"largura": _estado["largura"], "espelhar": _estado["espelhar"]}
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
	if is_inside_tree() and _aba == "grafismos" and _miniaturas.size() < PinturaCarro.PADROES.size():
		_gerar_miniaturas()
