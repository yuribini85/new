class_name Cabecalho
extends Control
## Cabeçalho das telas, como no exemplo do pack "Cabeçalho" (arte/ui/cabecalho/):
## uma faixa escura de borda a borda com voltar, divisória, título da tela, a
## diagonal ocre de altura inteira e o painel de giros (moeda, valor em Racing
## Sans One, "GIROS"). O banner de cada tela vem colado logo abaixo da faixa
## (Aba.cenario_topo). A faixa começa no topo absoluto; os elementos ficam
## abaixo da área segura do aparelho (`definir_area_segura`).

signal voltar

const PASTA := "res://arte/ui/cabecalho/"
const ALTURA := 84  # faixa dos elementos (px da tela de 720)
const COR_FAIXA := Color("16191c")
const COR_TITULO := Color("e6ddcd")
const COR_NUMERO := Color("c89b57")  # ocre dessaturado do pack
const COR_ROTULO := Color("b9bbbe")
const TAMANHO_NUMERO := 40
const OPACIDADE_SEM_VOLTA := 0.8  # 20% de transparência, sem toque
## Quanto cada texto sobe (px) para o centro das letras cair no centro da faixa,
## junto com o voltar, a moeda e o painel. Medido na tela renderizada (a caixa
## de cada fonte não tem as letras no meio: Barlow e Racing Sans One diferem).
const DESVIO_TITULO := 1.7
const DESVIO_NUMERO := 0.0
const DESVIO_GIROS := -1.0

var titulo: Label
var numero: Label
var painel: Control
var botao_voltar: TextureButton
var _fundo: ColorRect
var _faixa: HBoxContainer
var _area_segura := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo = ColorRect.new()
	_fundo.color = COR_FAIXA
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP  # a faixa não deixa o toque passar
	add_child(_fundo)
	_faixa = HBoxContainer.new()
	_faixa.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_faixa.add_theme_constant_override("separation", 0)
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_faixa)
	# Voltar: o quadrado escuro do pack, na mesma cor da faixa.
	botao_voltar = TextureButton.new()
	botao_voltar.texture_normal = load(PASTA + "voltar.png")
	botao_voltar.ignore_texture_size = true
	botao_voltar.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	botao_voltar.custom_minimum_size = Vector2(ALTURA * 0.95, ALTURA)
	botao_voltar.pressed.connect(func(): voltar.emit())
	_faixa.add_child(botao_voltar)
	_imagem("divisoria.png", Vector2(ALTURA * 12.0 / 125.0, ALTURA))
	_espaco(26)
	titulo = Label.new()
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.clip_text = true
	titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Tipografia.rotulo(titulo, "semibold", 54)
	titulo.add_theme_color_override("font_color", COR_TITULO)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(_centrado(titulo, DESVIO_TITULO))
	# Espaço da diagonal, que é desenhada junto do painel (abaixo).
	_espaco(ALTURA * 0.42)
	# Painel de giros: moldura do pack com moeda, número e "GIROS" por cima.
	var h_painel := ALTURA * 0.66
	var caixa := CenterContainer.new()
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(caixa)
	painel = TextureRect.new()
	(painel as TextureRect).texture = load(PASTA + "painel_giros.png")
	(painel as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	(painel as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Proporção original: a borda inclinada fica no mesmo ângulo da diagonal.
	painel.custom_minimum_size = Vector2(h_painel * 611.0 / 109.0, h_painel)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(painel)
	# Diagonal ocre da altura inteira da faixa, paralela à borda inclinada do
	# painel e bem perto dela (como no exemplo). Só escala, sem esticar.
	var diag := TextureRect.new()
	diag.texture = load(PASTA + "diagonal.png")
	diag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diag.size = Vector2(ALTURA * 88.0 / 119.0, ALTURA)
	diag.position = Vector2(-ALTURA * 0.36, (h_painel - ALTURA) / 2.0)
	diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(diag)
	var dentro := HBoxContainer.new()
	dentro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dentro.offset_left = h_painel * 0.75  # depois da borda inclinada
	dentro.offset_right = -h_painel * 0.22
	dentro.add_theme_constant_override("separation", 8)
	dentro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(dentro)
	var moeda := TextureRect.new()
	moeda.texture = load(PASTA + "icone_giros.png")
	moeda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moeda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moeda.custom_minimum_size = Vector2(h_painel * 0.55, h_painel * 0.66)
	moeda.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	moeda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dentro.add_child(moeda)
	numero = Label.new()
	numero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Tipografia.numero(numero, TAMANHO_NUMERO)
	numero.add_theme_color_override("font_color", COR_NUMERO)
	numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dentro.add_child(_centrado(numero, DESVIO_NUMERO))
	var giros := Label.new()
	giros.text = "GIROS"
	giros.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Tipografia.rotulo(giros, "semibold", 20)
	giros.add_theme_color_override("font_color", COR_ROTULO)
	giros.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caixa_giros := _centrado(giros, DESVIO_GIROS)
	caixa_giros.custom_minimum_size.x = Tipografia.fonte("semibold").get_string_size("GIROS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 2.0
	dentro.add_child(caixa_giros)
	_espaco(12)
	_posicionar()


## Distância do topo até a área segura (recorte da câmera, barra do sistema):
## a faixa cobre esse trecho; os elementos ficam abaixo dele.
func definir_area_segura(cima: float) -> void:
	_area_segura = cima
	_posicionar()


## Altura total da faixa (área segura + elementos): onde o conteúdo começa.
func altura_total() -> float:
	return _area_segura + ALTURA


func _posicionar() -> void:
	_faixa.offset_top = _area_segura
	_faixa.offset_bottom = _area_segura + ALTURA
	offset_bottom = altura_total()


## Valor dos giros, encolhendo a fonte se não couber na moldura.
func definir_giros(texto: String) -> void:
	numero.text = texto
	var f := Tipografia.fonte_numero()
	var livre := maxf(numero.size.x, 110.0)
	var tam := TAMANHO_NUMERO
	while tam > 20 and f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > livre:
		tam -= 2
	numero.add_theme_font_size_override("font_size", tam)


## Voltar habilitado só quando há tela anterior; sem ela, 80% de opacidade.
func definir_volta(possivel: bool) -> void:
	botao_voltar.disabled = not possivel
	botao_voltar.mouse_filter = Control.MOUSE_FILTER_STOP if possivel else Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(botao_voltar, "modulate:a", 1.0 if possivel else OPACIDADE_SEM_VOLTA, 0.2)


func _imagem(arquivo: String, tam: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(PASTA + arquivo)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # só escala, nunca estica
	t.custom_minimum_size = tam
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(t)
	return t


## Rótulo dentro de uma caixa da altura da faixa, subido `desvio` px: o centro
## das letras cai exatamente no centro da faixa, junto com as imagens.
func _centrado(l: Label, desvio: float) -> Control:
	var caixa := Control.new()
	caixa.size_flags_horizontal = l.size_flags_horizontal
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_FILL
	caixa.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_top = -desvio
	l.offset_bottom = -desvio
	return caixa


func _espaco(largura: float) -> void:
	var e := Control.new()
	e.custom_minimum_size = Vector2(largura, 0)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(e)
