class_name CartazCarro
extends Control
## Fundo de pôster atrás do carro nos cartões (decisão 127, D2, sem artista):
## um sol em degradê na cor do carro e faixas diagonais de velocidade. Só
## desenho; fica atrás da foto e não recebe toque.

var cor := Color.WHITE:
	set(v):
		cor = v
		queue_redraw()


func _init(cor_: Color = Color.WHITE) -> void:
	cor = cor_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func _draw() -> void:
	var c := Vector2(size.x * 0.55, size.y * 0.55)
	var raio := minf(size.x, size.y) * 0.62
	var clara := cor.lightened(0.25)
	# Sol: anéis concêntricos do mais fraco (fora) ao mais forte (dentro).
	for k in 6:
		var f := 1.0 - k / 6.0
		draw_circle(c, raio * f, Color(clara, 0.05 + 0.03 * k))
	# Faixas diagonais de velocidade, da esquerda para a direita e para cima.
	var passo := size.y * 0.16
	for k in 5:
		var y := size.y * 0.25 + k * passo
		var a := Vector2(-size.x * 0.1, y + size.x * 0.25)
		var b := Vector2(size.x * 1.1, y - size.x * 0.25)
		draw_line(a, b, Color(1, 1, 1, 0.05 if k % 2 == 0 else 0.03), passo * 0.35)
