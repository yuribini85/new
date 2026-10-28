class_name MolduraDeco
extends Control
## Moldura art déco por cima de um painel (The Fastfather,
## docs/idle/identidade_fastfather.md): filete duplo de latão com os cantos em
## degrau, como as molduras de elevador, cinema e cofre dos anos 1930. Não
## recebe toque; cobre o pai inteiro.

## Apresentação, não balanceamento.
const LATAO := IdleUI.COR_LATAO
var recuo := 6.0
var degrau := 10.0
var cor := LATAO


func _init(recuo_ := 6.0, cor_ := LATAO) -> void:
	recuo = recuo_
	cor = cor_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	# Dentro de um PanelContainer o filho fica na área do conteúdo: a moldura
	# volta para a borda do painel, por fora do texto.
	var r := Rect2(Vector2.ZERO, size)
	var pai := get_parent() as PanelContainer
	if pai != null:
		var sb := pai.get_theme_stylebox("panel")
		if sb != null:
			r = Rect2(-Vector2(sb.content_margin_left, sb.content_margin_top),
					size + Vector2(sb.content_margin_left + sb.content_margin_right, sb.content_margin_top + sb.content_margin_bottom))
	MolduraDeco.desenhar(self, r.grow(-recuo), cor, degrau)


## O filete duplo com cantos em degrau num retângulo qualquer.
static func desenhar(ci: CanvasItem, r: Rect2, c: Color, d := 10.0) -> void:
	var fora := _contorno(r, d)
	ci.draw_polyline(fora, c, 2.0)
	ci.draw_polyline(_contorno(r.grow(-5.0), maxf(d - 4.0, 3.0)), Color(c, 0.55), 1.0)
	# Losango em cada canto, a joia da moldura.
	for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), c)


static func _contorno(r: Rect2, d: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	var h := d * 0.5
	# Cada canto: dois degraus para dentro.
	return PackedVector2Array([
		Vector2(a.x + d, a.y), Vector2(b.x - d, a.y), Vector2(b.x - d, a.y + h), Vector2(b.x - h, a.y + h),
		Vector2(b.x - h, a.y + d), Vector2(b.x, a.y + d), Vector2(b.x, b.y - d), Vector2(b.x - h, b.y - d),
		Vector2(b.x - h, b.y - h), Vector2(b.x - d, b.y - h), Vector2(b.x - d, b.y), Vector2(a.x + d, b.y),
		Vector2(a.x + d, b.y - h), Vector2(a.x + h, b.y - h), Vector2(a.x + h, b.y - d), Vector2(a.x, b.y - d),
		Vector2(a.x, a.y + d), Vector2(a.x + h, a.y + d), Vector2(a.x + h, a.y + h), Vector2(a.x + d, a.y + h),
		Vector2(a.x + d, a.y)])
