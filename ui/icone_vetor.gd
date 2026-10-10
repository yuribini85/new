class_name IconeVetor
extends Control
## Ícone desenhado por código (provisório até a arte do pack): "engrenagem"
## (configurações), "acelerar" (corridas aceleradas, dois triângulos), "bandeira"
## (voltar à corrida, quadriculada) e os das
## câmeras da corrida: "camera" (AUTO, o diretor), "seta" (o seu carro, a
## mesma seta que fica sobre ele), "coroa" (líder), "frente" (o carro à
## frente), "pista" (visão geral) e "dados" (vista tática). Escala com o
## tamanho, sem esticar: o desenho usa o menor lado.

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
		"camera":
			_camera(c, lado * 0.5)
		"seta":
			_poligono(c, lado * 0.5, [[-0.62, -0.42], [0.62, -0.42], [0.0, 0.58]])
		"coroa":
			_poligono(c, lado * 0.5, [[-0.82, 0.55], [-0.82, -0.42], [-0.4, 0.04], [0.0, -0.62], [0.4, 0.04],
					[0.82, -0.42], [0.82, 0.55]])
		"frente":
			_frente(c, lado * 0.5)
		"pista":
			_pista(c, lado * 0.5)
		"dados":
			_dados(c, lado * 0.5)
		"grade":
			for k in 4:
				var q := c + Vector2(-0.82 + (k % 2) * 0.92, -0.82 + (k / 2) * 0.92) * lado * 0.5
				draw_rect(Rect2(q, Vector2(0.72, 0.72) * lado * 0.5), cor)
		"bandeira":
			_bandeira(c, lado * 0.5)
		"check":
			var r := lado * 0.5
			draw_polyline(PackedVector2Array([c + Vector2(-0.7, 0.0) * r, c + Vector2(-0.2, 0.5) * r,
					c + Vector2(0.75, -0.55) * r]), cor, maxf(r * 0.28, 2.0), true)
		"x":
			var r := lado * 0.5
			var w := maxf(r * 0.28, 2.0)
			draw_line(c + Vector2(-0.6, -0.6) * r, c + Vector2(0.6, 0.6) * r, cor, w, true)
			draw_line(c + Vector2(0.6, -0.6) * r, c + Vector2(-0.6, 0.6) * r, cor, w, true)
		"lista":
			for k in 3:
				var y := c.y + (-0.7 + k * 0.7) * lado * 0.5
				draw_rect(Rect2(Vector2(c.x - 0.85 * lado * 0.5, y - 0.12 * lado * 0.5), Vector2(1.7, 0.26) * lado * 0.5), cor)


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


## Bandeira quadriculada de chegada (sem mastro).
func _bandeira(c: Vector2, r: float) -> void:
	var w := r * 1.8
	var h := r * 1.3
	var topo := c - Vector2(w, h) * 0.5
	draw_rect(Rect2(topo, Vector2(w, h)), cor, false, maxf(r * 0.08, 1.0))
	var n := Vector2i(4, 3)
	var q := Vector2(w / n.x, h / n.y)
	for i in n.x:
		for j in n.y:
			if (i + j) % 2 == 0:
				draw_rect(Rect2(topo + Vector2(i * q.x, j * q.y), q), cor)


func _acelerar(c: Vector2, r: float) -> void:
	var h := r * 0.82
	var w := r * 0.92
	for k in 2:
		var x0 := c.x - w + k * w
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0, c.y - h), Vector2(x0 + w, c.y), Vector2(x0, c.y + h)]), cor)


func _poligono(c: Vector2, r: float, pontos: Array) -> void:
	var p := PackedVector2Array()
	for q in pontos:
		p.append(c + Vector2(q[0], q[1]) * r)
	draw_colored_polygon(p, cor)


func _traco(r: float) -> float:
	return maxf(2.0, r * 0.16)


func _camera(c: Vector2, r: float) -> void:
	draw_rect(Rect2(c + Vector2(-0.95, -0.5) * r, Vector2(1.2, 1.0) * r), cor)
	_poligono(c, r, [[0.32, 0.0], [0.95, -0.48], [0.95, 0.48]])


func _frente(c: Vector2, r: float) -> void:
	for k in 2:
		var y := -0.5 + k * 0.55
		draw_polyline(PackedVector2Array([c + Vector2(-0.62, y + 0.45) * r, c + Vector2(0.0, y) * r,
				c + Vector2(0.62, y + 0.45) * r]), cor, _traco(r), true)


func _pista(c: Vector2, r: float) -> void:
	var p := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		p.append(c + Vector2(cos(a) * 0.86, sin(a) * 0.52) * r)
	draw_polyline(p, cor, _traco(r), true)
	draw_circle(c + Vector2(0.86, 0.0) * r, r * 0.17, cor)


func _dados(c: Vector2, r: float) -> void:
	var w := 0.4 * r
	var base := c.y + 0.62 * r
	for k in 3:
		var h: float = [0.62, 1.2, 0.86][k] * r
		draw_rect(Rect2(c.x + (-0.8 + k * 0.6) * r, base - h, w, h), cor)
