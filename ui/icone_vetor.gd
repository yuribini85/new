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
		"velocimetro":
			# Mostrador em 6 segmentos (de 200° a 340°, com folgas) e o ponteiro
			# saindo do cubo vazado, para a direita e para cima.
			var r := lado * 0.5
			var centro := c + Vector2(0, 0.22) * r
			var segs := 6
			var ini := deg_to_rad(160.0)
			var fim := deg_to_rad(380.0)
			var folga := deg_to_rad(5.0)
			for k in segs:
				var a0 := lerpf(ini, fim, float(k) / segs) + folga * 0.5
				var a1 := lerpf(ini, fim, float(k + 1) / segs) - folga * 0.5
				var pts := PackedVector2Array()
				for i in 7:
					pts.append(centro + Vector2.from_angle(lerpf(a0, a1, i / 6.0)) * r * 0.95)
				for i in 7:
					pts.append(centro + Vector2.from_angle(lerpf(a1, a0, i / 6.0)) * r * 0.68)
				draw_colored_polygon(pts, cor)
			var ponta := centro + Vector2.from_angle(deg_to_rad(-32.0)) * r * 0.72
			var lado_p := Vector2.from_angle(deg_to_rad(-32.0)).orthogonal() * r * 0.12
			draw_colored_polygon(PackedVector2Array([centro + lado_p, ponta, centro - lado_p]), cor)
			draw_circle(centro, r * 0.24, cor)
			draw_circle(centro, r * 0.08, cor_fundo)
		"mira":
			# Anel em quatro arcos, as quatro barras arredondadas nas folgas e o ponto.
			var r := lado * 0.5
			var folga := deg_to_rad(16.0)
			for q in 4:
				var a0 := q * PI / 2.0 + folga
				var a1 := (q + 1) * PI / 2.0 - folga
				draw_arc(c, r * 0.6, a0, a1, 16, cor, r * 0.14, true)
			var esp := r * 0.16
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var p0: Vector2 = c + d * r * 0.42
				var p1: Vector2 = c + d * r * 0.96
				draw_line(p0, p1, cor, esp, true)
				draw_circle(p0, esp * 0.5, cor)
				draw_circle(p1, esp * 0.5, cor)
			draw_circle(c, r * 0.17, cor)
		"punho":
			# Punho erguido, inclinado: quatro dedos dobrados, o polegar por cima,
			# o dorso e o pulso (silhueta, sem contorno).
			var r := lado * 0.5
			var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * r
			var dedos := [
				[p.call(-0.3, -0.86), p.call(-0.08, -0.9), p.call(0.08, -0.82), p.call(-0.16, -0.45), p.call(-0.4, -0.55)],
				[p.call(0.12, -0.7), p.call(0.3, -0.66), p.call(0.38, -0.56), p.call(0.08, -0.17), p.call(-0.1, -0.3)],
				[p.call(0.4, -0.5), p.call(0.55, -0.42), p.call(0.6, -0.32), p.call(0.28, 0.05), p.call(0.14, -0.04)],
				[p.call(0.62, -0.26), p.call(0.74, -0.18), p.call(0.76, -0.08), p.call(0.47, 0.22), p.call(0.36, 0.13)],
			]
			for dd in dedos:
				draw_colored_polygon(PackedVector2Array(dd), cor)
			# Dorso e pulso.
			draw_colored_polygon(PackedVector2Array([p.call(-0.48, -0.58), p.call(-0.12, -0.42), p.call(0.1, -0.05),
					p.call(0.32, 0.12), p.call(0.48, 0.3), p.call(0.66, 0.06), p.call(0.62, 0.38), p.call(0.3, 0.75),
					p.call(0.36, 1.0), p.call(-0.28, 1.0), p.call(-0.16, 0.7), p.call(-0.78, -0.12)]), cor)
			# Polegar dobrado por cima dos dedos (a folga do fundo o separa).
			draw_polyline(PackedVector2Array([p.call(-0.42, -0.22), p.call(-0.12, -0.05), p.call(0.12, -0.08)]),
					cor_fundo, maxf(r * 0.06, 1.5), true)
			draw_polyline(PackedVector2Array([p.call(-0.12, -0.05), p.call(0.2, 0.42)]), cor_fundo,
					maxf(r * 0.05, 1.5), true)
		"cronometro":
			var r := lado * 0.5
			var w := maxf(r * 0.14, 2.0)
			draw_arc(c + Vector2(0, 0.12) * r, r * 0.72, 0.0, TAU, 32, cor, w, true)
			draw_rect(Rect2(c + Vector2(-0.18, -0.92) * r, Vector2(0.36, 0.2) * r), cor)
			draw_line(c + Vector2(0, 0.12) * r, c + Vector2(0, -0.32) * r, cor, w, true)
			draw_line(c + Vector2(0, 0.12) * r, c + Vector2(0.3, 0.3) * r, cor, w, true)
		"chevron":
			var r := lado * 0.5
			draw_polyline(PackedVector2Array([c + Vector2(-0.3, -0.62) * r, c + Vector2(0.32, 0.0) * r,
					c + Vector2(-0.3, 0.62) * r]), cor, maxf(r * 0.2, 2.0), true)
		"x":
			var r := lado * 0.5
			var w := maxf(r * 0.28, 2.0)
			draw_line(c + Vector2(-0.6, -0.6) * r, c + Vector2(0.6, 0.6) * r, cor, w, true)
			draw_line(c + Vector2(0.6, -0.6) * r, c + Vector2(-0.6, 0.6) * r, cor, w, true)
		"pincel":
			# Rolo de pintura: o rolo, o braço e o cabo.
			var r := lado * 0.5
			var w := maxf(r * 0.16, 2.0)
			draw_rect(Rect2(c + Vector2(-0.85, -0.85) * r, Vector2(1.4, 0.55) * r), cor)
			draw_polyline(PackedVector2Array([c + Vector2(0.55, -0.58) * r, c + Vector2(0.85, -0.58) * r,
					c + Vector2(0.85, -0.05) * r, c + Vector2(0.0, -0.05) * r, c + Vector2(0.0, 0.25) * r]), cor, w, true)
			draw_rect(Rect2(c + Vector2(-0.14, 0.2) * r, Vector2(0.28, 0.7) * r), cor)
		"peca":
			# Porca sextavada: o recurso Peças.
			var r := lado * 0.5
			var hexa := PackedVector2Array()
			for k in 6:
				hexa.append(c + Vector2.from_angle(TAU * k / 6.0 + PI / 6.0) * r * 0.92)
			draw_colored_polygon(hexa, cor)
			draw_circle(c, r * 0.4, cor_fundo)
		"desfazer", "refazer":
			# Seta curva para trás (desfazer) ou para a frente (refazer).
			var r := lado * 0.5
			var w := maxf(r * 0.2, 2.0)
			var e := -1.0 if tipo == "desfazer" else 1.0
			var arco := PackedVector2Array()
			for k in 13:
				var a := lerpf(PI * 0.15, PI * 1.05, k / 12.0)
				arco.append(c + Vector2(cos(a) * e * -1.0, -sin(a)) * r * 0.62 + Vector2(0, r * 0.2))
			draw_polyline(arco, cor, w, true)
			var ponta := arco[arco.size() - 1]
			draw_colored_polygon(PackedVector2Array([ponta + Vector2(0, -0.32) * r, ponta + Vector2(0, 0.32) * r,
					ponta + Vector2(e * 0.38, 0.0) * r]), cor)
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
