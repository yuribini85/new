class_name IconeVetor
extends Control
## Ícone desenhado por código (provisório até a arte do pack): "engrenagem"
## (configurações) e "acelerar" (corridas aceleradas, dois triângulos). Escala
## com o tamanho, sem esticar: o desenho usa o menor lado.

var tipo := ""
var cor := Color.WHITE:
	set(v):
		cor = v
		queue_redraw()
## Cor do furo da engrenagem (a do fundo onde ela está).
var cor_fundo := Color.BLACK


func _init(tipo_: String = "", cor_: Color = Color.WHITE) -> void:
	tipo = tipo_
	cor = cor_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var lado := minf(size.x, size.y)
	var c := size / 2.0
	match tipo:
		"engrenagem":
			_engrenagem(c, lado * 0.5)
		"acelerar":
			_acelerar(c, lado * 0.5)


func _engrenagem(c: Vector2, r: float) -> void:
	var dentes := 8
	var externo := r
	var interno := r * 0.74
	var pontos := PackedVector2Array()
	for i in dentes:
		var base := TAU * i / dentes
		var meio := TAU / dentes
		# Dente: topo um pouco mais estreito que a base.
		for a in [[-0.30, interno], [-0.18, externo], [0.18, externo], [0.30, interno]]:
			pontos.append(c + Vector2.from_angle(base + a[0] * meio) * a[1])
	draw_colored_polygon(pontos, cor)
	draw_circle(c, interno * 0.98, cor)
	draw_circle(c, r * 0.32, cor_fundo)


func _acelerar(c: Vector2, r: float) -> void:
	var h := r * 0.82
	var w := r * 0.92
	for k in 2:
		var x0 := c.x - w + k * w
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0, c.y - h), Vector2(x0 + w, c.y), Vector2(x0, c.y + h)]), cor)
