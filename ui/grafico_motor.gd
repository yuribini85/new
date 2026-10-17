class_name GraficoMotor
extends Control
## Potência (cv) por giro (rpm) de uma ou mais curvas de motor, com o corte
## marcado. Lê os atributos efetivos (curva_rpm, curva_nm, corte) do Carro:
## a mesma curva que a simulação usa. Serve para mostrar a FORMA de uma peça
## (turbo concentra no giro alto, preparação aspirada estica o giro).

## [{rotulo, cor, attrs}]
var curvas: Array = []


func _init(curvas_: Array = [], altura := 200.0) -> void:
	curvas = curvas_
	custom_minimum_size = Vector2(0, altura)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func tem_curva(attrs: Dictionary) -> bool:
	return attrs.has("curva_rpm") and attrs.has("curva_nm")


## Pontos (rpm, cv) até o corte.
static func pontos(attrs: Dictionary) -> Array:
	var r := []
	var rpm: PackedFloat64Array = attrs["curva_rpm"]
	var nm: PackedFloat64Array = attrs["curva_nm"]
	for i in rpm.size():
		if rpm[i] > float(attrs["corte"]) + 1.0:
			break
		r.append(Vector2(rpm[i], nm[i] * rpm[i] * Carro.CV_POR_NM_RPM))
	return r


## Onde a peça mexe na curva, em uma frase: giro alto, baixo, por igual, e se
## o corte subiu. "" se não há curva.
static func forma_do_ganho(antes: Dictionary, depois: Dictionary) -> String:
	if not tem_curva(antes) or not tem_curva(depois):
		return ""
	var a := pontos(antes)
	var d := pontos(depois)
	if a.is_empty() or d.is_empty():
		return ""
	var r0: float = a[0].x
	var r1: float = a[a.size() - 1].x
	# Ganho relativo (%): peça de ganho uniforme dá o mesmo percentual em todo
	# o giro, mesmo que em cv o ganho pareça maior onde a curva é mais alta.
	var baixo := _ganho_medio(a, d, r0, r0 + (r1 - r0) / 3.0)
	var alto := _ganho_medio(a, d, r1 - (r1 - r0) / 3.0, r1)
	var partes := []
	if absf(alto) < 0.005 and absf(baixo) < 0.005:
		pass
	elif absf(alto - baixo) < 0.02:
		partes.append("ganho por igual em todo o giro")
	elif alto > baixo:
		partes.append("ganho concentrado no giro alto")
	else:
		partes.append("ganho concentrado no giro baixo")
	var dc := float(depois["corte"]) - float(antes["corte"])
	if dc >= 50.0:
		partes.append("corte sobe %d rpm (até %d)" % [roundi(dc), roundi(float(depois["corte"]))])
	if partes.is_empty():
		return ""
	var texto := "; ".join(partes)
	return texto.left(1).to_upper() + texto.substr(1)


static func _ganho_medio(a: Array, d: Array, de: float, ate: float) -> float:
	var soma := 0.0
	var n := 0
	for k in 9:
		var rpm := lerpf(de, ate, k / 8.0)
		soma += _cv_em(d, rpm) / maxf(_cv_em(a, rpm), 1e-6) - 1.0
		n += 1
	return soma / n


static func _cv_em(pts: Array, rpm: float) -> float:
	if rpm <= pts[0].x:
		return pts[0].y
	for i in range(1, pts.size()):
		if rpm <= pts[i].x:
			return lerpf(pts[i - 1].y, pts[i].y, (rpm - pts[i - 1].x) / maxf(pts[i].x - pts[i - 1].x, 1.0))
	return pts[pts.size() - 1].y


func _draw() -> void:
	var listas := []
	var rmin := INF
	var rmax := 0.0
	var cvmax := 1.0
	for c in curvas:
		if not tem_curva(c["attrs"]):
			continue
		var p := pontos(c["attrs"])
		if p.is_empty():
			continue
		listas.append([c, p])
		rmin = minf(rmin, p[0].x)
		rmax = maxf(rmax, maxf(p[p.size() - 1].x, float(c["attrs"]["corte"])))
		for q in p:
			cvmax = maxf(cvmax, q.y)
	if listas.is_empty():
		return
	var m := Rect2(Vector2(52, 8), size - Vector2(60, 40))
	draw_rect(m, Color(1, 1, 1, 0.04))
	var fonte := get_theme_default_font()
	var fs := 18
	var xy := func(rpm: float, cv: float) -> Vector2:
		return m.position + Vector2((rpm - rmin) / maxf(rmax - rmin, 1.0) * m.size.x, m.size.y * (1.0 - cv / (cvmax * 1.08)))
	# Grade: três linhas de potência, rótulos de rpm nas pontas.
	for k in range(1, 4):
		var cv := cvmax * 1.08 * k / 4.0
		var y: float = xy.call(rmin, cv).y
		draw_line(Vector2(m.position.x, y), Vector2(m.end.x, y), Color(1, 1, 1, 0.08))
		draw_string(fonte, Vector2(4, y + 6), "%d" % roundi(cv), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.5))
	draw_string(fonte, Vector2(m.position.x, size.y - 6), "%d rpm" % roundi(rmin), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.5))
	draw_string(fonte, Vector2(m.end.x - 110, size.y - 6), "%d rpm" % roundi(rmax), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.5))
	draw_string(fonte, Vector2(4, m.position.y + 4), "cv", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.5))
	for par in listas:
		var c: Dictionary = par[0]
		var p: Array = par[1]
		var linha := PackedVector2Array()
		for q in p:
			linha.append(xy.call(q.x, q.y))
		draw_polyline(linha, c["cor"], 3.0, true)
		var xc: float = xy.call(float(c["attrs"]["corte"]), 0.0).x
		draw_dashed_line(Vector2(xc, m.position.y), Vector2(xc, m.end.y), Color(c["cor"], 0.6), 2.0, 6.0)
	# Legenda.
	var x := m.position.x + 8.0
	for par in listas:
		var c: Dictionary = par[0]
		draw_rect(Rect2(Vector2(x, m.position.y + 6), Vector2(14, 14)), c["cor"])
		draw_string(fonte, Vector2(x + 20, m.position.y + 19), c["rotulo"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		x += 30.0 + fonte.get_string_size(c["rotulo"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
