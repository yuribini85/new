class_name BarraDentes
extends Control
## Barra de evolução em dentes: um segmento inclinado (gume) por estágio de
## peça; os comprados acesos em ocre, os que faltam apagados. Com muitos
## estágios, até MAX_DENTES segmentos, acesos na proporção.

const MAX_DENTES := 10
const INCLINACAO := 0.55  # deslocamento do topo de cada dente, em fração da altura
const VAO := 3.0
const ACESO := Color("c89b57")
const APAGADO := Color(1, 1, 1, 0.16)

var feitos := 0
var total := 0


func _init(feitos_: int = 0, total_: int = 0, altura := 9.0) -> void:
	feitos = feitos_
	total = total_
	custom_minimum_size = Vector2(0, altura)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if total <= 0:
		return
	var n := mini(total, MAX_DENTES)
	var acesos := feitos if total <= MAX_DENTES else roundi(float(feitos) / total * n)
	var h := size.y
	var dx := h * INCLINACAO
	var w := (size.x - dx - VAO * (n - 1)) / n
	for i in n:
		var x := i * (w + VAO)
		draw_colored_polygon(PackedVector2Array([Vector2(x + dx, 0), Vector2(x + dx + w, 0), Vector2(x + w, h),
				Vector2(x, h)]), ACESO if i < acesos else APAGADO)
