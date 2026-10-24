class_name CaixaAbrindo
extends Control
## A caixa de pintura abrindo na janela do resultado (decisão 130, E4: "abre na
## hora, com animação curta"): a caixa treme, a tampa salta com faíscas e o que
## saiu aparece embaixo. Só desenho; o item já foi liberado (CaixaPintura.abrir).

const DURA_S := 1.4
const COR_CAIXA := Color("8a5a2b")
const COR_FITA := Color("ffd34d")

var _t := 0.0
var _rotulo: Label


func _init(texto: String) -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo = Label.new()
	_rotulo.text = texto
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_rotulo.offset_top = -40
	Tipografia.rotulo(_rotulo, "semibold", 24)
	_rotulo.add_theme_color_override("font_color", COR_FITA)
	_rotulo.modulate.a = 0.0
	add_child(_rotulo)
	if Preferencias.reduzir_animacoes:
		_t = DURA_S


func _process(delta: float) -> void:
	if _t >= DURA_S:
		_rotulo.modulate.a = 1.0
		set_process(false)
		queue_redraw()
		return
	_t += delta
	_rotulo.modulate.a = clampf((_t - 0.7) / 0.3, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var meio := Vector2(size.x * 0.5, 62.0)
	# 0..0,5 s treme; depois a tampa salta e as faíscas abrem.
	var treme := 0.0 if _t > 0.5 else sin(_t * 60.0) * 4.0 * (1.0 - _t / 0.5)
	var abre := clampf((_t - 0.5) / 0.4, 0.0, 1.0)
	var corpo := Rect2(meio + Vector2(-38.0 + treme, -10.0), Vector2(76.0, 56.0))
	draw_rect(corpo, COR_CAIXA)
	draw_rect(Rect2(corpo.position + Vector2(32.0, 0.0), Vector2(12.0, corpo.size.y)), COR_FITA)
	if abre > 0.0:
		# Brilho de dentro e faíscas em leque.
		draw_circle(meio + Vector2(0.0, -10.0), 30.0 * abre, Color(COR_FITA, 0.35 * (1.0 - abre * 0.5)))
		for k in 9:
			var ang := PI + PI * (k + 0.5) / 9.0
			var dir := Vector2.from_angle(ang)
			var a := meio + Vector2(0.0, -12.0) + dir * 20.0 * abre
			var b := a + dir * 26.0 * abre
			draw_line(a, b, Color(COR_FITA, 1.0 - abre * 0.6), 3.0)
	var tampa := Rect2(meio + Vector2(-44.0 + treme, -22.0 - 40.0 * abre), Vector2(88.0, 14.0))
	draw_set_transform(tampa.get_center(), -0.5 * abre, Vector2.ONE)
	draw_rect(Rect2(-tampa.size * 0.5, tampa.size), COR_CAIXA.lightened(0.15))
	draw_rect(Rect2(Vector2(-6.0, -tampa.size.y * 0.5), Vector2(12.0, tampa.size.y)), COR_FITA)
	draw_set_transform(Vector2.ZERO)
