class_name ArenaForma
extends RefCounted
## Forma de uma arena (decisão 59): o muro em polígono (cantos e reentrâncias,
## não um círculo), obstáculos no meio (ilhas de pneus, pilhas de carcaças:
## círculos) e o relevo do chão, que não é plano, desenhado como curvas de
## nível (decisão 78): montes e crateras (gaussianas de altura `h` e raio `r`),
## valas e diques ("vala": ao longo de a→b, `largura`, `fundo` plano), rampas
## ("rampa": sobe de a até `h` em b e cai em `queda` m) e platôs ou poços de
## topo plano ("plato": círculo c/r ou polígono `pontos`, com `encosta`); a
## borda sobe junto ao muro. Os termos se somam; os de `max: true` assentam por
## cima (a rampa que leva ao platô não o dobra).
## O relevo entra na física: a gravidade puxa o carro morro abaixo (a cratera
## arrasta a briga para o fundo; a lombada desvia quem passa). A mesma forma
## desenha o chão e põe os carros na altura certa (Arena3D).
## Sem forma em data/arena.json, o círculo de `raio_m`, plano (o de antes).

const LADOS_CIRCULO := 64

var muro := PackedVector2Array()  # anti-horário, em m
var obstaculos: Array = []  # [{c: Vector2, r: float}]
var relevo: Array = []  # [{tipo, h, ...}] (ver _termo)
var borda_largura := 0.0
var borda_altura := 0.0
var centro := Vector2.ZERO
## Subida (pedido do usuário): a força do motor cai com a inclinação contra o
## carro, além da gravidade (patina e perde embalo na rampa). Provisório.
var subida_perda := 0.0
var id := ""
var nome := ""


static func de(params: Dictionary) -> ArenaForma:
	var f := ArenaForma.new()
	f.subida_perda = float(params.get("subida_perda", 0.0))
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
		f.relevo.append(_ler_termo(r))
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


static func _v(q: Array) -> Vector2:
	return Vector2(float(q[0]), float(q[1]))


static func _ler_termo(r: Dictionary) -> Dictionary:
	var t := {"tipo": String(r.get("tipo", "monte")), "h": float(r["h"]), "max": bool(r.get("max", false))}
	match t["tipo"]:
		"vala":
			t["a"] = _v(r["a"])
			t["b"] = _v(r["b"])
			t["meia"] = float(r["largura"]) * 0.5
			t["meio_fundo"] = float(r.get("fundo", 0.0)) * 0.5
		"rampa":
			t["a"] = _v(r["a"])
			t["b"] = _v(r["b"])
			t["meia"] = float(r["largura"]) * 0.5
			t["queda"] = float(r.get("queda", 3.0))
			t["encosta"] = float(r.get("encosta", maxf(1.5, absf(float(r["h"])) * 1.2)))  # o lado da rampa
		"plato":
			t["encosta"] = float(r.get("encosta", 3.0))
			if r.has("pontos"):
				var pts := PackedVector2Array()
				for q in r["pontos"]:
					pts.append(_v(q))
				t["pontos"] = pts
			else:
				t["c"] = _v(r["c"])
				t["r"] = float(r["r"])
		_:
			t["c"] = _v(r["c"])
			t["r"] = float(r["r"])
	return t


## Um termo do relevo em `p` (m).
static func _termo(t: Dictionary, p: Vector2) -> float:
	var h: float = t["h"]
	match t["tipo"]:
		"vala":
			var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, t["a"], t["b"]))
			var meia: float = t["meia"]
			var mf: float = t["meio_fundo"]
			return h * (1.0 - smoothstep(0.0, 1.0, clampf((d - mf) / maxf(meia - mf, 0.01), 0.0, 1.0)))
		"rampa":
			var a: Vector2 = t["a"]
			var eixo: Vector2 = t["b"] - a
			var comp := eixo.length()
			var dir := eixo / comp
			var u := (p - a).dot(dir)
			var v := absf((p - a).dot(dir.orthogonal()))
			var ao_longo := 0.0
			if u >= 0.0 and u <= comp:
				ao_longo = u / comp
			elif u > comp and u < comp + float(t["queda"]):
				ao_longo = 1.0 - smoothstep(0.0, float(t["queda"]), u - comp)
			var meia: float = t["meia"]
			return h * ao_longo * (1.0 - smoothstep(meia, meia + float(t["encosta"]), v))
		"plato":
			var d := 0.0
			if t.has("pontos"):
				var pts: PackedVector2Array = t["pontos"]
				if not Geometry2D.is_point_in_polygon(p, pts):
					d = INF
					for i in pts.size():
						d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[(i + 1) % pts.size()])))
			else:
				var c: Vector2 = t["c"]
				d = maxf(p.distance_to(c) - float(t["r"]), 0.0)
			return h * (1.0 - smoothstep(0.0, float(t["encosta"]), d))
	var s: float = float(t["r"]) * 0.5
	var cm: Vector2 = t["c"]
	return h * exp(-p.distance_squared_to(cm) / (2.0 * s * s))


## Altura do chão em `p` (m): os termos do relevo e a borda subindo para o muro.
func altura(p: Vector2) -> float:
	return altura_com_muro(p, muro_perto(p)[0] if borda_largura > 0.0 else 0.0)


## A mesma altura, com a distância ao muro (muro_perto) já calculada: o chão da
## tela a usa também para a grama, sem medir duas vezes.
func altura_com_muro(p: Vector2, dm: float) -> float:
	var h := 0.0
	for t in relevo:
		if not t["max"]:
			h += _termo(t, p)
	for t in relevo:
		if t["max"]:
			# Só onde o termo existe: fora dele (v≈0) não apaga uma vala nem um poço.
			var v := _termo(t, p)
			var peso := minf(absf(v) / (0.3 * absf(float(t["h"]))), 1.0)
			h = lerpf(h, maxf(h, v) if float(t["h"]) > 0.0 else minf(h, v), peso)
	if borda_largura > 0.0:
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
