class_name ArenaForma
extends RefCounted
## Forma de uma arena (decisão 59): o muro em polígono (cantos e reentrâncias,
## não um círculo), obstáculos no meio (ilhas de pneus, pilhas de carcaças:
## círculos) e o relevo do chão, que não é plano: lombadas e crateras
## (gaussianas de altura `h` e raio `r`) e a borda que sobe junto ao muro.
## O relevo entra na física: a gravidade puxa o carro morro abaixo (a cratera
## arrasta a briga para o fundo; a lombada desvia quem passa). A mesma forma
## desenha o chão e põe os carros na altura certa (Arena3D).
## Sem forma em data/arena.json, o círculo de `raio_m`, plano (o de antes).

const LADOS_CIRCULO := 64

var muro := PackedVector2Array()  # anti-horário, em m
var obstaculos: Array = []  # [{c: Vector2, r: float}]
var relevo: Array = []  # [{c: Vector2, r: float, h: float}]
var borda_largura := 0.0
var borda_altura := 0.0
var centro := Vector2.ZERO
var id := ""
var nome := ""


static func de(params: Dictionary) -> ArenaForma:
	var f := ArenaForma.new()
	var d: Dictionary = params.get("forma", {})
	if d.is_empty():
		var raio := float(params["raio_m"])
		for k in LADOS_CIRCULO:
			f.muro.append(Vector2.from_angle(TAU * k / LADOS_CIRCULO) * raio)
		return f
	f.id = String(d.get("id", ""))
	f.nome = String(d.get("nome", ""))
	for p in d["muro"]:
		f.muro.append(Vector2(float(p[0]), float(p[1])))
	if Geometry2D.is_polygon_clockwise(f.muro):
		f.muro.reverse()
	for o in d.get("obstaculos", []):
		f.obstaculos.append({"c": Vector2(float(o["c"][0]), float(o["c"][1])), "r": float(o["r"])})
	for r in d.get("relevo", []):
		f.relevo.append({"c": Vector2(float(r["c"][0]), float(r["c"][1])), "r": float(r["r"]), "h": float(r["h"])})
	var borda: Dictionary = d.get("borda", {})
	f.borda_largura = float(borda.get("largura", 0.0))
	f.borda_altura = float(borda.get("altura", 0.0))
	for p in f.muro:
		f.centro += p / f.muro.size()
	return f


func dentro(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, muro)


## [distância ao muro mais próximo, normal apontando para dentro da arena].
func muro_perto(p: Vector2) -> Array:
	var melhor := INF
	var nrm := Vector2.ZERO
	for i in muro.size():
		var a := muro[i]
		var b := muro[(i + 1) % muro.size()]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < melhor:
			melhor = d
			# Anti-horário: o lado de dentro fica à esquerda da aresta.
			nrm = (b - a).normalized().orthogonal() * -1.0
	return [melhor if dentro(p) else -melhor, nrm]


## Obstáculo mais próximo de `p`: [folga (distância à borda dele), normal para
## fora dele]; sem obstáculos, [INF, zero].
func obstaculo_perto(p: Vector2) -> Array:
	var melhor := INF
	var nrm := Vector2.ZERO
	for o in obstaculos:
		var d: Vector2 = p - o["c"]
		var folga: float = d.length() - float(o["r"])
		if folga < melhor:
			melhor = folga
			nrm = d.normalized() if d.length() > 1e-6 else Vector2.RIGHT
	return [melhor, nrm]


## Altura do chão em `p` (m): lombadas (+) e crateras (−), e a borda subindo
## para o muro.
func altura(p: Vector2) -> float:
	var h := 0.0
	for r in relevo:
		var s: float = float(r["r"]) * 0.5
		h += float(r["h"]) * exp(-p.distance_squared_to(r["c"]) / (2.0 * s * s))
	if borda_largura > 0.0:
		var dm: float = muro_perto(p)[0]
		h += borda_altura * (1.0 - smoothstep(0.0, borda_largura, maxf(dm, 0.0)))
	return h


## Inclinação do chão (gradiente da altura).
func gradiente(p: Vector2) -> Vector2:
	if relevo.is_empty() and borda_largura <= 0.0:
		return Vector2.ZERO
	var e := 0.5
	return Vector2(altura(p + Vector2(e, 0)) - altura(p - Vector2(e, 0)),
			altura(p + Vector2(0, e)) - altura(p - Vector2(0, e))) / (2.0 * e)


## Ponto da largada na direção `ang` a partir do centro: `frac` do caminho até
## o muro (fora dos obstáculos).
func largada(ang: float, frac: float) -> Vector2:
	var dir := Vector2.from_angle(ang)
	var longe := INF
	for i in muro.size():
		var x = Geometry2D.segment_intersects_segment(centro, centro + dir * 10000.0, muro[i], muro[(i + 1) % muro.size()])
		if x != null:
			longe = minf(longe, centro.distance_to(x))
	if longe == INF:
		longe = 10.0
	return centro + dir * longe * frac


## Área dentro do muro (m²).
func area() -> float:
	var a := 0.0
	for i in muro.size():
		a += muro[i].cross(muro[(i + 1) % muro.size()])
	return absf(a) * 0.5
