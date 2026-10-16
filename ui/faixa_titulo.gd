class_name FaixaTitulo
extends Control
## Faixa atrás do título de impacto (arte de referência do usuário): duas
## linhas finas em cima e embaixo, os riscos inclinados à esquerda e manchas de
## tinta nas pontas, com respingos que somem. O título fica entre as linhas
## (de MEIO_Y[0] a MEIO_Y[1] da altura). Desenhada por código, sempre igual.

const MEIO_Y := Vector2(0.22, 0.77)
const TEXTO_X := 0.17  # onde o título começa (fração da largura)

var cor := Aba.COR_DESTAQUE


func _init(cor_: Color = Aba.COR_DESTAQUE) -> void:
	cor = cor_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _p(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)


func _poli(pts: Array, c := cor) -> void:
	var v := PackedVector2Array()
	for q in pts:
		v.append(_p(q[0], q[1]))
	draw_colored_polygon(v, c)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var linha := maxf(size.y * 0.018, 2.0)
	# Linhas de cima e de baixo, e a quina da esquerda que desce inclinada.
	draw_line(_p(0.2, MEIO_Y.x), _p(0.8, MEIO_Y.x), cor, linha)
	draw_line(_p(0.08, MEIO_Y.y), _p(0.74, MEIO_Y.y), cor, linha)
	draw_polyline(PackedVector2Array([_p(0.2, MEIO_Y.x), _p(0.14, MEIO_Y.x), _p(0.13, 0.33), _p(0.065, MEIO_Y.y)]),
			cor, linha)
	# Riscos da esquerda: dois blocos inclinados e os dois finos no alto.
	_poli([[0.11, 0.17], [0.15, 0.17], [0.07, 0.59], [0.03, 0.59]])
	_poli([[0.1, 0.45], [0.14, 0.45], [0.04, 0.98], [0.005, 0.98]])
	_poli([[0.215, 0.0], [0.225, 0.0], [0.195, 0.2], [0.185, 0.2]])
	_poli([[0.235, 0.0], [0.24, 0.0], [0.21, 0.2], [0.205, 0.2]])
	# Manchas de tinta: embaixo à esquerda, em cima e no meio à direita.
	_mancha(rng, Vector2(0.06, MEIO_Y.y), Vector2(0.4, 0.99), true)
	_mancha(rng, Vector2(0.8, 0.0), Vector2(0.98, MEIO_Y.x), false)
	_mancha(rng, Vector2(0.74, 0.51), Vector2(0.93, 0.8), false)


## Bloco inclinado de tinta que se desfaz em respingos para a direita.
func _mancha(rng: RandomNumberGenerator, de: Vector2, ate: Vector2, cheio_esq: bool) -> void:
	var h := ate.y - de.y
	var inclina := h * 0.45
	var corpo_fim := lerpf(de.x, ate.x, 0.45 if cheio_esq else 0.55)
	_poli([[de.x + inclina, de.y], [corpo_fim + inclina, de.y], [corpo_fim, ate.y], [de.x, ate.y]])
	# Falhas escuras dentro do bloco.
	for k in 26:
		var y := rng.randf_range(de.y, ate.y)
		var x := rng.randf_range(de.x + inclina * (1.0 - (y - de.y) / h), corpo_fim)
		draw_circle(_p(x, y), rng.randf_range(0.6, 1.6), Color(0.1, 0.08, 0.04, 0.5))
	# Respingos que somem até `ate.x`.
	for k in 70:
		var t := pow(rng.randf(), 1.4)
		var x := lerpf(corpo_fim, ate.x, t)
		var y := rng.randf_range(de.y, ate.y)
		var c := cor
		c.a = 1.0 - t * 0.85
		draw_rect(Rect2(_p(x, y), Vector2(rng.randf_range(1.5, 4.0), rng.randf_range(1.5, 4.0))), c)
