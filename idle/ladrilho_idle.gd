class_name LadrilhoIdle
extends PanelContainer
## Cartão compacto da tela da corrida (layout do usuário, 2026-10-27): na
## Oficina do Tony, a peça grande no alto, o nome e o nível, o efeito e o botão
## verde com o preço; nas Trapaças da família, uma linha com o ícone, o nome, o
## que faz e o preço. Fechado: escuro, com o cadeado e a linha de quando abre.

signal comprar

## Apresentação, não balanceamento.
const VERDE := Color("7fcf7a")
const VERDE_ESCURO := Color("3f8a45")
const FUNDO := Color("1f1a15")
const FUNDO_FECHADO := Color("15120f")

var id: String
var nome: Label
var nivel: Label
var efeito: Label
var botao: Button
var _icone: TextureRect
var _fechado := false
var _pequeno := false


## `pequeno`: a linha das trapaças (ícone à esquerda, sem a peça grande).
func _init(id_: String, icone: String, texto: String, pequeno := false) -> void:
	id = id_
	_pequeno = pequeno
	add_theme_stylebox_override("panel", IdleUI.caixa(FUNDO, 6, 8, IdleUI.COR_BORDA, 1))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	if pequeno:
		# Trapaça: o nome, o que faz e, no botão, o nível e o preço (sem
		# ícone pequeno: pedido do usuário).
		nome = IdleUI.rotulo(texto.to_upper(), 17, IdleUI.COR_TEXTO, v, "display")
		nome.clip_text = true
		efeito = IdleUI.rotulo("", 15, IdleUI.COR_CROMO, v)
		efeito.clip_text = true
		nivel = Label.new()  # o nível entra no texto do botão
		nivel.visible = false
		v.add_child(nivel)
		_icone = TextureRect.new()
	else:
		_icone = TextureRect.new()  # sem ícone no cartão (pedido do usuário)
		nome = IdleUI.rotulo(texto.to_upper(), 18, IdleUI.COR_TEXTO, v, "display")
		nome.clip_text = true
		var h := HBoxContainer.new()
		v.add_child(h)
		efeito = IdleUI.rotulo("", 17, VERDE, h)
		efeito.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		efeito.clip_text = true
		nivel = IdleUI.rotulo("", 13, IdleUI.COR_CROMO, h)
	_icone.visible = false  # sem ícones nos cartões (pedido do usuário)
	v.add_child(_icone)
	# O botão no pé do cartão: na mesma altura em toda a linha.
	var vao := Control.new()
	vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(vao)
	botao = Button.new()
	botao.focus_mode = Control.FOCUS_NONE
	botao.custom_minimum_size = Vector2(0, 40 if pequeno else 46)
	botao.add_theme_font_override("font", Tipografia.fonte("display"))
	botao.add_theme_font_size_override("font_size", 24 if pequeno else 26)
	for estado_botao in ["normal", "hover", "focus"]:
		botao.add_theme_stylebox_override(estado_botao, IdleUI.caixa(VERDE, 5, 4, VERDE_ESCURO, 1))
	botao.add_theme_stylebox_override("pressed", IdleUI.caixa(VERDE.darkened(0.15), 5, 4, VERDE_ESCURO, 1))
	botao.add_theme_stylebox_override("disabled", IdleUI.caixa(Color("2b2621"), 5, 4, Color("3a332b"), 1))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		botao.add_theme_color_override(c, IdleUI.COR_TINTA)
	botao.add_theme_color_override("font_disabled_color", IdleUI.COR_BLOQUEADO.lightened(0.25))
	botao.pressed.connect(func(): comprar.emit())
	v.add_child(botao)


## Preço no botão e se dá para pagar; o efeito e o nível no cartão.
func definir(texto_nivel: String, texto_efeito: String, preco: String, pode: bool) -> void:
	nivel.text = texto_nivel
	efeito.text = texto_efeito
	botao.text = "%s · %s" % [texto_nivel, preco] if _pequeno else preco
	var antes := botao.disabled
	botao.disabled = not pode
	if antes and pode and is_visible_in_tree():
		IdleUI.pulsar(botao, 1.08)


## Ainda não aberto: escuro, com a linha de quando abre no lugar do efeito.
func fechar(texto: String) -> void:
	_fechado = true
	add_theme_stylebox_override("panel", IdleUI.caixa(FUNDO_FECHADO, 6, 8, Color("2b2621"), 1))
	_icone.modulate = Color(0.12, 0.11, 0.1)
	nome.add_theme_color_override("font_color", IdleUI.COR_BLOQUEADO)
	efeito.text = texto
	efeito.add_theme_color_override("font_color", IdleUI.COR_BLOQUEADO)
	nivel.text = ""
	botao.text = "FECHADO"
	botao.disabled = true


func esta_fechado() -> bool:
	return _fechado


func abrir() -> void:
	if not _fechado:
		return
	_fechado = false
	add_theme_stylebox_override("panel", IdleUI.caixa(FUNDO, 6, 8, IdleUI.COR_BORDA, 1))
	_icone.modulate = Color.WHITE
	nome.remove_theme_color_override("font_color")
	efeito.add_theme_color_override("font_color", IdleUI.COR_CROMO if _pequeno else VERDE)
