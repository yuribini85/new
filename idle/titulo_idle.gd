class_name TituloIdle
extends Control
## Tela de título do Chrome Racing Team (docs/idle/direcao.md): a oficina da Mara
## com o portão aceso, embaixo do outdoor da Moretti Speedway, o logotipo e
## "TOQUE PARA COMEÇAR". Aparece ao abrir o app; um toque fecha com um fade.

signal fechou

## Apresentação, não balanceamento.
const SAIDA_S := 0.35
const CEU_ALTO := Color("141a26")
const CEU_BAIXO := Color("1b2333")
const PREDIO := Color("0d1118")
const VERMELHO := Color("e5484d")
const LUZ := Color("ffc53d")

var _toque: Label
var _t := 0.0
var _saindo := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var logo := TextureRect.new()
	logo.texture = load("res://arte/idle/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	logo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	logo.offset_left = 30
	logo.offset_right = -30
	logo.offset_top = -470
	logo.offset_bottom = -210
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	_toque = IdleUI.rotulo("TOQUE PARA COMEÇAR", 26, IdleUI.COR_CROMO)
	_toque.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toque.offset_top = -170
	_toque.offset_bottom = -110
	_toque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toque)


func _process(delta: float) -> void:
	_t += delta
	_toque.modulate.a = 0.55 + 0.45 * absf(sin(_t * 1.6))
	queue_redraw()


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
	Sons.tocar_ui(self, "toque", -6.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.0 if Preferencias.reduzir_animacoes else SAIDA_S)
	tw.tween_callback(func():
		fechou.emit()
		queue_free())


func _draw() -> void:
	var w := size.x
	var h := size.y
	var chao := h * 0.58
	# Céu em faixas (sem degradê difuso) e prédios em planos.
	for k in 6:
		draw_rect(Rect2(0, chao * k / 6.0, w, chao / 6.0 + 1), CEU_ALTO.lerp(CEU_BAIXO, k / 5.0))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, chao), Vector2(w * 0.3, h * 0.24), Vector2(w * 0.6, h * 0.2),
			Vector2(w * 0.78, h * 0.25), Vector2(w * 0.78, chao)]), PREDIO)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.74, chao), Vector2(w * 0.74, h * 0.12), Vector2(w, h * 0.1),
			Vector2(w, chao)]), PREDIO.darkened(0.2))
	# Outdoor da Moretti Speedway, inclinado, com brilho vermelho.
	var o := Vector2(w * 0.38, h * 0.27)
	var ow := w * 0.56
	var oh := 120.0
	var brilho := 0.35 + 0.1 * sin(_t * 3.0)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-14, -10), o + Vector2(ow + 14, -24), o + Vector2(ow + 14, oh + 4),
			o + Vector2(-14, oh + 18)]), Color(VERMELHO, brilho * 0.4))
	draw_colored_polygon(PackedVector2Array([o, o + Vector2(ow, -14), o + Vector2(ow, oh - 6), o + Vector2(0, oh + 8)]),
			Color("1a0f10"))
	draw_polyline(PackedVector2Array([o, o + Vector2(ow, -14), o + Vector2(ow, oh - 6), o + Vector2(0, oh + 8), o]), VERMELHO, 4.0)
	var fonte := Tipografia.fonte("display")
	draw_string(fonte, o + Vector2(18, 52), "MORETTI", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color("ffdcdc"))
	draw_string(fonte, o + Vector2(18, 98), "SPEEDWAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, Color("ffdcdc"))
	draw_rect(Rect2(0, chao + 120, w, h - chao - 120), Color("090c11"))
	draw_rect(Rect2(0, chao, w, 120), Color("0c1016"))
	# A oficina da Mara: telhado facetado, portão aceso e a luz no chão.
	var g := Vector2(w * 0.05, chao)
	draw_colored_polygon(PackedVector2Array([g, g + Vector2(0, -150), g + Vector2(110, -190), g + Vector2(230, -150),
			g + Vector2(230, 0)]), Color("151b24"))
	draw_colored_polygon(PackedVector2Array([g + Vector2(40, 0), g + Vector2(40, -96), g + Vector2(190, -102),
			g + Vector2(190, 0)]), LUZ.lerp(Color("f08a0c"), 0.4))
	draw_colored_polygon(PackedVector2Array([g + Vector2(40, 0), g + Vector2(190, 0), g + Vector2(300, 120),
			g + Vector2(-40, 120)]), Color(LUZ, 0.16))
	# A Mara em silhueta no portão.
	var m := g + Vector2(118, 0)
	draw_colored_polygon(PackedVector2Array([m + Vector2(-16, 0), m + Vector2(-12, -46), m + Vector2(-18, -80),
			m + Vector2(-7, -94), m + Vector2(7, -94), m + Vector2(18, -80), m + Vector2(12, -46), m + Vector2(16, 0)]),
			Color("0b0e13"))
	draw_circle(m + Vector2(0, -106), 12, Color("0b0e13"))
