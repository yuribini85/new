class_name TituloIdle
extends Control
## Tela de título do The Fastfather (docs/idle/identidade_fastfather.md): fundo
## preto, o logo e "TOQUE PARA COMEÇAR". Aparece ao abrir o app; um toque fecha.

signal fechou
signal saindo  # começou a sumir: o que vem depois já pode entrar por baixo

## Apresentação, não balanceamento.
const SAIDA_S := 0.35

var _toque: Label
var _fundo: Control
var _t := 0.0
var _saindo := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Fundo preto liso (pedido do usuário): só o logo.
	_fundo = ColorRect.new()
	(_fundo as ColorRect).color = Color.BLACK
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)
	var logo := TextureRect.new()
	logo.texture = load("res://arte/idle/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	logo.offset_left = -330
	logo.offset_right = 330
	logo.offset_top = -330
	logo.offset_bottom = 110
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	_toque = IdleUI.rotulo("TOQUE PARA COMEÇAR", 26, IdleUI.COR_CROMO, null, "deco")
	_toque.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toque.offset_top = -200
	_toque.offset_bottom = -130
	_toque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toque.add_theme_constant_override("outline_size", 8)
	_toque.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_toque)


func _process(delta: float) -> void:
	_t += delta
	_toque.modulate.a = 0.55 + 0.45 * absf(sin(_t * 1.6))


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if toque:
		accept_event()
		fechar()


func fechar() -> void:
	if _saindo:
		return
	_saindo = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	saindo.emit()
	Sons.tocar_ui(self, "toque", -6.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.0 if Preferencias.reduzir_animacoes else SAIDA_S)
	tw.tween_callback(func():
		fechou.emit()
		queue_free())
