class_name Pincel
extends Control
## Pincelada inclinada atrás de um título: uma faixa com as bordas rasgadas,
## falhas de tinta e respingos. Desenhada por código, sempre igual para a
## mesma `semente` (não pisca ao redesenhar).

var cor := Aba.COR_DESTAQUE
var semente := 7
var inclinacao := 0.22  # quanto o topo avança em relação à base (fração da altura)


func _init(cor_: Color = Aba.COR_DESTAQUE, semente_ := 7) -> void:
	cor = cor_
	semente = semente_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var desloca := h * inclinacao
	# Faixa principal: borda de cima e de baixo com dentes de tamanho variado.
	var cima := PackedVector2Array()
	var baixo := PackedVector2Array()
	var passos := maxi(int(w / 9.0), 8)
	for k in passos + 1:
		var t := float(k) / passos
		var x := t * (w - desloca)
		cima.append(Vector2(x + desloca, rng.randf_range(0.0, h * 0.14)))
		baixo.append(Vector2(x, h - rng.randf_range(0.0, h * 0.16)))
	var poli := PackedVector2Array(cima)
	baixo.reverse()
	poli.append_array(baixo)
	draw_colored_polygon(poli, cor)
	# Falhas de tinta: riscos escuros finos ao longo da faixa.
	var falha := Color(0.05, 0.05, 0.06, 0.55)
	for k in int(w / 28.0):
		var y := rng.randf_range(h * 0.2, h * 0.85)
		var x0 := rng.randf_range(0.0, w * 0.9)
		var comp := rng.randf_range(w * 0.04, w * 0.16)
		draw_line(Vector2(x0 + desloca * (1.0 - y / h), y), Vector2(x0 + comp + desloca * (1.0 - y / h), y),
				falha, rng.randf_range(1.0, 2.5))
	# Respingos na ponta da direita e na esquerda.
	for k in 14:
		var lado := 1.0 if k % 3 else 0.0
		var x := lerpf(rng.randf_range(-w * 0.04, w * 0.06), rng.randf_range(w * 0.9, w * 1.04), lado)
		var y := rng.randf_range(h * 0.05, h * 0.95)
		draw_rect(Rect2(x, y, rng.randf_range(2.0, 7.0), rng.randf_range(2.0, 5.0)), cor)
