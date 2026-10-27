class_name CarroEpoca
extends RefCounted
## Carros de época gerados em código (conversão máfia 1930–1950,
## docs/idle/conversao_mafia.md, 6): carroceria de peças separadas como nos
## carros de 1928–1950 — capô estreito entre para-lamas soltos, estribo, grade
## de radiador em pé, faróis em tigela numa barra, para-choque de lâminas,
## estepe atrás e rodas de raios de arame. Nenhum emblema nem nome de fábrica.
##
## Mesmo sistema de eixos e nós dos carros gerados (Carroceria): frente em +Z,
## chão em y = 0, malha "Carroceria" com a pintura numa superfície (meta
## "pintura") e as rodas em nós Mount_* (metas "lado" e "raio") que giram em X.
## As medidas são de apresentação (metros), por modelo em MODELOS.

## Ângulo máximo entre faces vizinhas que viram superfície lisa.
const SUAVE_GRAUS := 34.0

## Cupê de duas portas de 1928 (Corridas de Bairro): entre-eixos de 2,63 m,
## bitola de 1,42 m, pneus altos e finos em aro 21", 1,73 m de altura.
## Corpo: [z, meia largura, base, topo, raio da quina de cima] de trás para a
## frente. Cabine: idem, da cintura ao teto. Para-lama: [z, altura do topo,
## abaulado] do bico do para-lama dianteiro, pelo estribo, ao fim do traseiro.
const MODELOS := {
	"cupe_1928": {
		"eixos": [1.315, -1.315], "bitola": 1.42, "r": 0.38, "aro": 0.27, "pneu": 0.115, "raios": 30,
		"corpo": [[-1.82, 0.36, 0.70, 0.72, 0.04], [-1.76, 0.50, 0.64, 0.80, 0.10], [-1.62, 0.58, 0.60, 0.92, 0.16],
			[-1.38, 0.63, 0.58, 1.01, 0.16], [-1.10, 0.65, 0.58, 1.07, 0.12], [-0.86, 0.66, 0.58, 1.11, 0.06],
			[-0.40, 0.66, 0.58, 1.12, 0.05], [0.10, 0.65, 0.59, 1.13, 0.05], [0.24, 0.58, 0.60, 1.15, 0.06],
			[0.34, 0.42, 0.63, 1.165, 0.07], [0.46, 0.335, 0.66, 1.165, 0.07], [0.90, 0.30, 0.66, 1.17, 0.07],
			[1.30, 0.27, 0.66, 1.18, 0.07]],
		"cabine": [[-0.88, 0.58, 1.10, 1.40, 0.16], [-0.84, 0.61, 1.10, 1.60, 0.24], [-0.74, 0.62, 1.10, 1.70, 0.2],
			[-0.40, 0.625, 1.10, 1.735, 0.12], [0.05, 0.625, 1.10, 1.735, 0.12], [0.22, 0.615, 1.10, 1.715, 0.12],
			[0.28, 0.60, 1.10, 1.68, 0.10]],
		"paralama_frente": [[1.84, 0.58, 0.02], [1.76, 0.72, 0.05], [1.64, 0.83, 0.07], [1.48, 0.885, 0.08],
			[1.30, 0.895, 0.08], [1.13, 0.86, 0.08], [0.99, 0.78, 0.07], [0.88, 0.66, 0.05], [0.78, 0.565, 0.03],
			[0.64, 0.515, 0.01]],
		"estribo": [0.64, -0.86, 0.505],
		"paralama_tras": [[-0.86, 0.515, 0.01], [-0.96, 0.58, 0.03], [-1.05, 0.70, 0.06], [-1.15, 0.80, 0.08],
			[-1.30, 0.86, 0.08], [-1.46, 0.85, 0.08], [-1.60, 0.79, 0.07], [-1.72, 0.68, 0.05], [-1.80, 0.56, 0.02]],
		"paralama_largura": [0.56, 0.86],
		"radiador": {"z": 1.30, "fundo": 0.07, "meia": 0.255, "base": 0.50, "topo": 1.23},
		"farol": {"z": 1.52, "x": 0.40, "y": 0.92, "r": 0.105},
		"vidros": {"porta": [0.17, -0.30, 1.19, 1.58], "lateral": [-0.38, -0.70, 1.21, 1.56],
			"para_brisa": [0.54, 1.17, 1.62], "vigia": [0.24, 1.30, 1.48]},
		"portas": [0.215, -0.335],
	},
}

static var _corpos := {}  # modelo -> ArrayMesh
static var _rodas := {}  # modelo|lado -> ArrayMesh


static func tem(modelo: String) -> bool:
	return MODELOS.has(modelo)


## O carro montado: carroceria pintada na cor e as quatro rodas.
static func construir(modelo: String, cor: Color, faixas: Dictionary = {}) -> Node3D:
	if not tem(modelo):
		return null
	var f: Dictionary = MODELOS[modelo]
	var raiz := Node3D.new()
	raiz.name = "Gerado"
	var mi := MeshInstance3D.new()
	mi.name = "Carroceria"
	mi.mesh = corpo(modelo)
	raiz.add_child(mi)
	var k := int(mi.mesh.get_meta("pintura", -1))
	if k >= 0:
		var sm := ShaderMaterial.new()
		sm.shader = CarroBloco.SHADER_LATARIA
		sm.set_shader_parameter("cor_base", cor)
		mi.set_surface_override_material(k, sm)
		CarroBloco._parametros_faixas(sm, mi, faixas)
	var r := float(f["r"])
	var meia := float(f["bitola"]) * 0.5
	for p in [["Mount_FrontLeft", -1.0, 0], ["Mount_FrontRight", 1.0, 0], ["Mount_RearLeft", -1.0, 1],
			["Mount_RearRight", 1.0, 1]]:
		var roda := MeshInstance3D.new()
		roda.name = String(p[0])
		roda.mesh = roda_malha(modelo, float(p[1]))
		roda.position = Vector3(meia * float(p[1]), r, float(f["eixos"][p[2]]))
		roda.set_meta("lado", float(p[1]))
		roda.set_meta("raio", r)
		raiz.add_child(roda)
	return raiz


static func corpo(modelo: String) -> ArrayMesh:
	if not _corpos.has(modelo):
		var m := MontagemMalha.new()
		_montar(m, MODELOS[modelo])
		_corpos[modelo] = CarroBloco.suavizar_por_angulo(m.malha(), SUAVE_GRAUS, true)
	return _corpos[modelo]


static func _montar(m: MontagemMalha, f: Dictionary) -> void:
	_lataria(m, f)
	_cabine(m, f)
	_paralamas(m, f)
	_radiador(m, f)
	_farois(m, f)
	_para_choques(m, f)
	_chassi(m, f)
	_detalhes(m, f)
	_estepe(m, f)


# --- primitivas ---------------------------------------------------------------

## Seção de caixa com as quinas de cima arredondadas, no plano XY em z
## (pontos em volta, sempre o mesmo número).
static func _secao(z: float, meia: float, base: float, topo: float, raio: float) -> PackedVector3Array:
	var p := PackedVector3Array()
	var r := minf(raio, minf(meia, topo - base) * 0.95)
	var q := 4
	p.append(Vector3(-meia, base, z))
	p.append(Vector3(meia, base, z))
	for i in q + 1:  # quina direita de cima
		var a := PI * 0.5 * i / q
		p.append(Vector3(meia - r + r * cos(a), topo - r + r * sin(a), z))
	for i in q + 1:  # quina esquerda de cima
		var a := PI * 0.5 + PI * 0.5 * i / q
		p.append(Vector3(-meia + r + r * cos(a), topo - r + r * sin(a), z))
	return p


## Liga seções de mesmo número de pontos (anéis fechados) e tampa as pontas;
## cada face sai virada para fora do eixo das seções.
static func _loft(m: MontagemMalha, estilo: String, secoes: Array, tampar := true) -> void:
	for s in secoes.size() - 1:
		var a: PackedVector3Array = secoes[s]
		var b: PackedVector3Array = secoes[s + 1]
		var ca := _centro(a)
		var cb := _centro(b)
		var n := a.size()
		for i in n:
			var j := (i + 1) % n
			_face(m, estilo, [a[i], a[j], b[j], b[i]], (ca + cb) * 0.5)
	if tampar:
		_tampa(m, estilo, secoes[0], secoes[1])
		_tampa(m, estilo, secoes[-1], secoes[-2])


static func _centro(p: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in p:
		c += v
	return c / maxf(p.size(), 1)


## Quadrilátero (ou triângulo) virado para longe de `dentro`.
static func _face(m: MontagemMalha, estilo: String, q: Array, dentro: Vector3) -> void:
	var a: Vector3 = q[0]
	var b: Vector3 = q[1]
	var c: Vector3 = q[2]
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12 and q.size() > 3:
		n = (c - a).cross(q[3] - a)
	var fora := n.dot((a + b + c) / 3.0 - dentro) >= 0.0
	for t in ([[0, 1, 2], [0, 2, 3]] if q.size() > 3 else [[0, 1, 2]]):
		var p0: Vector3 = q[t[0]]
		var p1: Vector3 = q[t[1]]
		var p2: Vector3 = q[t[2]]
		if fora:
			m.tri(estilo, p0, p2, p1)
		else:
			m.tri(estilo, p0, p1, p2)


## Tampa de uma seção (leque a partir do centro), virada para longe da vizinha.
static func _tampa(m: MontagemMalha, estilo: String, s: PackedVector3Array, vizinha: PackedVector3Array) -> void:
	var c := _centro(s)
	var dentro := _centro(vizinha)
	for i in s.size():
		_face(m, estilo, [c, s[i], s[(i + 1) % s.size()]], dentro)


## Caixa entre dois cantos (alinhada aos eixos).
static func _bloco(m: MontagemMalha, estilo: String, a: Vector3, b: Vector3) -> void:
	m.caixa(estilo, (b - a).abs(), MontagemMalha.xf((a + b) * 0.5))


## Barra cilíndrica de `a` a `b`.
static func _barra(m: MontagemMalha, estilo: String, a: Vector3, b: Vector3, raio: float, lados := 8) -> void:
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var base := Basis(x, y, z)
	m.cilindro(estilo, raio, d.length(), lados, Transform3D(base, (a + b) * 0.5))


## Curva suave (Catmull-Rom) por pontos de controle, `por` amostras por trecho.
static func _suave(pts: Array, por: int) -> Array:
	var out := []
	for i in pts.size() - 1:
		var p0: Array = pts[maxi(i - 1, 0)]
		var p1: Array = pts[i]
		var p2: Array = pts[i + 1]
		var p3: Array = pts[mini(i + 2, pts.size() - 1)]
		for k in por:
			var t := float(k) / por
			var v := []
			for c in p1.size():
				v.append(0.5 * (2.0 * p1[c] + (-p0[c] + p2[c]) * t + (2.0 * p0[c] - 5.0 * p1[c] + 4.0 * p2[c] - p3[c]) * t * t
						+ (-p0[c] + 3.0 * p1[c] - 3.0 * p2[c] + p3[c]) * t * t * t))
			out.append(v)
	out.append(pts[-1])
	return out


# --- peças --------------------------------------------------------------------

## Capô, torpedo (a parte que alarga do capô para a cabine) e o corpo até a
## traseira arredondada: uma loft só, pintada.
static func _lataria(m: MontagemMalha, f: Dictionary) -> void:
	var secoes := []
	for s in _suave(f["corpo"], 3):
		secoes.append(_secao(s[0], s[1], s[2], s[3], s[4]))
	_loft(m, MontagemMalha.PINTURA, secoes)


## Cabine alta de teto quase reto, com vidros planos por fora, pala sobre o
## para-brisa e a lona preta no meio do teto.
static func _cabine(m: MontagemMalha, f: Dictionary) -> void:
	var secoes := []
	for s in _suave(f["cabine"], 3):
		secoes.append(_secao(s[0], s[1], s[2], s[3], s[4]))
	_loft(m, MontagemMalha.PINTURA, secoes)
	var v: Dictionary = f["vidros"]
	var meia := float(f["cabine"][3][1]) + 0.004
	for lado: float in [-1.0, 1.0]:
		for nome in ["porta", "lateral"]:
			var j: Array = v[nome]
			# moldura escura e o vidro
			_painel_lado(m, "preto", lado * meia, j[0] + 0.02, j[1] - 0.02, j[2] - 0.02, j[3] + 0.02)
			_painel_lado(m, "vidro_epoca", lado * (meia + 0.002), j[0], j[1], j[2], j[3])
	# Para-brisa em pé, em moldura, logo atrás do torpedo.
	var pb: Array = v["para_brisa"]
	var zf := float(f["cabine"][-1][0]) + 0.004
	_painel_frente(m, "preto", zf, pb[0] + 0.02, pb[1] - 0.02, pb[2] + 0.02)
	_painel_frente(m, "vidro_epoca", zf + 0.002, pb[0], pb[1], pb[2])
	# Vigia pequena atrás.
	var vg: Array = v["vigia"]
	var zt := float(f["cabine"][1][0]) - 0.004
	_painel_frente(m, "vidro_epoca", zt, vg[0], vg[1], vg[2], -1.0)
	# Pala sobre o para-brisa.
	var topo := float(f["cabine"][-1][3])
	_bloco(m, MontagemMalha.PINTURA, Vector3(-pb[0] - 0.03, topo - 0.035, zf - 0.02), Vector3(pb[0] + 0.03, topo - 0.01, zf + 0.20))
	# Lona do teto.
	var alto := float(f["cabine"][3][3])
	_bloco(m, "lona", Vector3(-0.44, alto - 0.01, -0.62), Vector3(0.44, alto + 0.008, 0.10))


## Painel retangular no lado (x fixo): z de `z0` a `z1`, y de `y0` a `y1`.
static func _painel_lado(m: MontagemMalha, estilo: String, x: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var d := Vector3(-signf(x), 0, 0) + Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
	_face(m, estilo, [Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0)], d)


## Painel virado para a frente (`sentido` +1) ou para trás (-1), em z.
static func _painel_frente(m: MontagemMalha, estilo: String, z: float, meia: float, y0: float, y1: float,
		sentido := 1.0) -> void:
	var d := Vector3(0, (y0 + y1) * 0.5, z - sentido)
	_face(m, estilo, [Vector3(-meia, y0, z), Vector3(meia, y0, z), Vector3(meia, y1, z), Vector3(-meia, y1, z)], d)


## Para-lamas soltos e abaulados, em preto brilhante, ligados pelo estribo:
## uma lâmina varrida pelo perfil lateral, com a borda de fora caindo.
static func _paralamas(m: MontagemMalha, f: Dictionary) -> void:
	var larg: Array = f["paralama_largura"]
	var est: Array = f["estribo"]
	var perfil: Array = _suave(f["paralama_frente"], 4)
	perfil.pop_back()
	perfil.append_array([[est[0], est[2], 0.01], [lerpf(est[0], est[1], 0.5), est[2], 0.01]])
	perfil.pop_back()
	var tras: Array = _suave(f["paralama_tras"], 4)
	perfil.append_array(tras)
	for lado: float in [-1.0, 1.0]:
		var secoes := []
		for i in perfil.size():
			var p: Array = perfil[i]
			var a: Array = perfil[maxi(i - 1, 0)]
			var b: Array = perfil[mini(i + 1, perfil.size() - 1)]
			# normal ao perfil no plano lateral (para cima e para fora da roda)
			var t := Vector2(float(b[0]) - float(a[0]), float(b[1]) - float(a[1])).normalized()
			var n := Vector2(-t.y, t.x)
			if n.y < 0.0:
				n = -n
			secoes.append(_secao_paralama(lado, float(larg[0]), float(larg[1]), Vector2(p[0], p[1]), n, float(p[2])))
		_loft(m, "paralama", secoes)
	# Estribo: tapete de borracha com friso.
	for lado: float in [-1.0, 1.0]:
		var x0 := lado * (float(larg[0]) + 0.02)
		var x1 := lado * (float(larg[1]) - 0.02)
		_bloco(m, "borracha", Vector3(minf(x0, x1), est[2] + 0.004, est[1] - 0.02), Vector3(maxf(x0, x1), est[2] + 0.012, est[0] + 0.02))
		_bloco(m, "cromo", Vector3(lado * float(larg[1]) - 0.008, est[2] - 0.02, est[1]), Vector3(lado * float(larg[1]) + 0.008, est[2] + 0.004, est[0]))


## Seção do para-lama: arco abaulado de dentro (x0) para fora (x1), espessura
## pequena; `n` é a normal do perfil (z, y) no ponto.
static func _secao_paralama(lado: float, x0: float, x1: float, o: Vector2, n: Vector2, abaulado: float) -> PackedVector3Array:
	var p := PackedVector3Array()
	var q := 8
	var esp := 0.025
	var cima := []
	for i in q + 1:
		var s := float(i) / q
		var h := abaulado * sin(PI * minf(s * 1.15, 1.0)) - (0.06 * pow(s, 6.0) if abaulado > 0.02 else 0.0)
		cima.append([lerpf(x0, x1, s), h])
	for c in cima:
		p.append(Vector3(lado * float(c[0]), o.y + n.y * float(c[1]), o.x + n.x * float(c[1])))
	for i in range(q, -1, -1):
		var c: Array = cima[i]
		var h := float(c[1]) - esp
		p.append(Vector3(lado * float(c[0]), o.y + n.y * h, o.x + n.x * h))
	return p


## Grade do radiador em pé: moldura cromada de cantos de cima arredondados,
## colmeia escura com barras, tampa no alto e o avental embaixo.
static func _radiador(m: MontagemMalha, f: Dictionary) -> void:
	var r: Dictionary = f["radiador"]
	var z0 := float(r["z"])
	var z1 := z0 + float(r["fundo"])
	var meia := float(r["meia"])
	var base := float(r["base"])
	var topo := float(r["topo"])
	_loft(m, "cromo", [_secao(z0, meia, base, topo, 0.09), _secao(z1, meia, base, topo, 0.09)])
	# colmeia (um pouco para dentro da moldura)
	var zc := z1 + 0.002
	_painel_frente(m, "interno", zc, meia - 0.05, base + 0.06, topo - 0.07)
	var n := 13
	for i in n:
		var x := lerpf(-meia + 0.07, meia - 0.07, float(i) / (n - 1))
		_bloco(m, "aro_escuro", Vector3(x - 0.004, base + 0.06, zc), Vector3(x + 0.004, topo - 0.07, zc + 0.006))
	# tampa do radiador e enfeite
	_barra(m, "cromo", Vector3(0, topo - 0.01, z0 + 0.035), Vector3(0, topo + 0.05, z0 + 0.035), 0.035, 10)
	_barra(m, "cromo", Vector3(0, topo + 0.05, z0 + 0.035), Vector3(0, topo + 0.07, z0 + 0.07), 0.012, 6)
	# avental embaixo da grade
	_bloco(m, "paralama", Vector3(-meia + 0.02, 0.44, z0 - 0.02), Vector3(meia - 0.02, base, z1 - 0.01))


## Faróis em tigela cromada numa barra entre os para-lamas.
static func _farois(m: MontagemMalha, f: Dictionary) -> void:
	var fa: Dictionary = f["farol"]
	var z := float(fa["z"])
	var y := float(fa["y"])
	var r := float(fa["r"])
	_barra(m, "cromo", Vector3(-float(fa["x"]) - 0.08, y - r - 0.06, z - 0.03), Vector3(float(fa["x"]) + 0.08, y - r - 0.06, z - 0.03), 0.018, 8)
	for lado: float in [-1.0, 1.0]:
		var x := lado * float(fa["x"])
		# tigela: meia esfera virada para trás + aro e lente na frente
		m.esfera("cromo", r, r * 2.0, 12, 8, MontagemMalha.xf(Vector3(x, y, z - 0.02), Vector3(PI / 2, 0, 0), Vector3(1, 0.9, 1)))
		m.cilindro("cromo", r * 1.04, 0.03, 14, MontagemMalha.xf(Vector3(x, y, z + 0.06), Vector3(PI / 2, 0, 0)))
		m.cilindro("lente", r * 0.9, 0.012, 14, MontagemMalha.xf(Vector3(x, y, z + 0.08), Vector3(PI / 2, 0, 0)))
		# haste até a barra
		_barra(m, "preto", Vector3(x, y - r * 0.8, z - 0.02), Vector3(x, y - r - 0.06, z - 0.03), 0.014, 6)


## Para-choques de duas lâminas cromadas na frente; atrás, dois pedaços.
static func _para_choques(m: MontagemMalha, f: Dictionary) -> void:
	var zf := float(f["paralama_frente"][0][0]) + 0.10
	for y: float in [0.42, 0.53]:
		_bloco(m, "cromo", Vector3(-0.80, y - 0.022, zf - 0.012), Vector3(0.80, y + 0.022, zf + 0.012))
	for lado: float in [-1.0, 1.0]:
		# braçadeiras nas pontas e os braços até o chassi
		_bloco(m, "cromo", Vector3(lado * 0.74 - 0.02, 0.40, zf - 0.02), Vector3(lado * 0.74 + 0.02, 0.555, zf + 0.02))
		_barra(m, "preto", Vector3(lado * 0.42, 0.47, zf - 0.01), Vector3(lado * 0.42, 0.50, zf - 0.40), 0.018, 6)
	var zt := float(f["paralama_tras"][-1][0]) - 0.12
	for lado: float in [-1.0, 1.0]:
		for y: float in [0.44, 0.55]:
			_bloco(m, "cromo", Vector3(minf(lado * 0.36, lado * 0.80), y - 0.02, zt - 0.012),
					Vector3(maxf(lado * 0.36, lado * 0.80), y + 0.02, zt + 0.012))
		_barra(m, "preto", Vector3(lado * 0.42, 0.49, zt + 0.01), Vector3(lado * 0.42, 0.52, zt + 0.35), 0.018, 6)


## Longarinas e eixos à vista embaixo, molas transversais e o tanque.
static func _chassi(m: MontagemMalha, f: Dictionary) -> void:
	var zf := float(f["paralama_frente"][0][0])
	var zt := float(f["paralama_tras"][-1][0])
	for lado: float in [-1.0, 1.0]:
		_bloco(m, "preto", Vector3(lado * 0.40 - 0.03, 0.47, zt), Vector3(lado * 0.40 + 0.03, 0.60, zf - 0.08))
	var meia := float(f["bitola"]) * 0.5
	for z in f["eixos"]:
		_barra(m, "preto", Vector3(-meia + 0.05, float(f["r"]), z), Vector3(meia - 0.05, float(f["r"]), z), 0.03, 6)
		_bloco(m, "preto", Vector3(-0.50, float(f["r"]) + 0.12, z - 0.03), Vector3(0.50, float(f["r"]) + 0.16, z + 0.03))
	# para-lama interno (avental) entre o capô e o para-lama dianteiro
	for lado: float in [-1.0, 1.0]:
		var x0 := lado * 0.30
		var x1 := lado * (float(f["paralama_largura"][0]) + 0.01)
		_bloco(m, "preto", Vector3(minf(x0, x1), 0.60, 0.40), Vector3(maxf(x0, x1), 0.63, 1.62))


## Venezianas do capô, linhas das portas, maçanetas, dobradiça do capô e a
## lanterna no para-lama traseiro esquerdo.
static func _detalhes(m: MontagemMalha, f: Dictionary) -> void:
	for lado: float in [-1.0, 1.0]:
		for i in 16:
			var z := lerpf(0.50, 0.86, float(i) / 15)
			var x := lado * (_meia_corpo(f, z) + 0.003)
			_bloco(m, "interno", Vector3(minf(x, x + lado * 0.006), 0.76, z - 0.007), Vector3(maxf(x, x + lado * 0.006), 0.90, z + 0.007))
		# faixa preta da cintura: da traseira da cabine até a grade, pelo capô
		var zs: Array = []
		for k in 25:
			zs.append(lerpf(-0.86, 1.30, float(k) / 24))
		for k in zs.size() - 1:
			var za: float = zs[k]
			var zb: float = zs[k + 1]
			var ya := _cintura(za)
			var yb := _cintura(zb)
			var xa := lado * (_meia_corpo(f, za) + 0.004)
			var xb := lado * (_meia_corpo(f, zb) + 0.004)
			_face(m, "paralama", [Vector3(xa, ya - 0.035, za), Vector3(xb, yb - 0.035, zb), Vector3(xb, yb + 0.012, zb),
					Vector3(xa, ya + 0.012, za)], Vector3(0, (ya + yb) * 0.5, (za + zb) * 0.5))
		# linhas da porta e maçaneta
		var xp := lado * (float(f["corpo"][7][1]) + 0.003)
		for z in f["portas"]:
			_bloco(m, "interno", Vector3(minf(xp, xp + lado * 0.004), 0.62, z - 0.004), Vector3(maxf(xp, xp + lado * 0.004), 1.10, z + 0.004))
		var xc := lado * (float(f["cabine"][3][1]) + 0.003)
		for z in f["portas"]:
			_bloco(m, "interno", Vector3(minf(xc, xc + lado * 0.004), 1.10, z - 0.004), Vector3(maxf(xc, xc + lado * 0.004), 1.62, z + 0.004))
		_bloco(m, "cromo", Vector3(minf(xp, xp + lado * 0.03), 1.04, float(f["portas"][1]) + 0.04),
				Vector3(maxf(xp, xp + lado * 0.03), 1.06, float(f["portas"][1]) + 0.13))
	# dobradiça do capô no meio
	_bloco(m, "cromo", Vector3(-0.012, 1.162, 0.34), Vector3(0.012, 1.175, 1.30))
	# lanterna
	m.cilindro("lanterna", 0.045, 0.06, 10, MontagemMalha.xf(Vector3(-0.72, 0.88, -1.62), Vector3(PI / 2, 0, 0)))
	_barra(m, "preto", Vector3(-0.72, 0.84, -1.62), Vector3(-0.72, 0.80, -1.56), 0.01, 6)


## Estepe em pé atrás da carroceria, no suporte.
static func _estepe(m: MontagemMalha, f: Dictionary) -> void:
	var r := float(f["r"])
	var z := float(f["corpo"][0][0]) - 0.07
	var y := r + 0.17
	var xf := Transform3D(Basis.from_euler(Vector3(0, PI / 2, 0)), Vector3(0, y, z))
	_roda_em(m, f, xf)
	_bloco(m, "preto", Vector3(-0.04, y - 0.05, z + 0.04), Vector3(0.04, y + 0.05, z + 0.10))


## Meia largura do corpo em z (interpolada nas seções).
static func _meia_corpo(f: Dictionary, z: float) -> float:
	var c: Array = f["corpo"]
	for i in c.size() - 1:
		if z >= float(c[i][0]) and z <= float(c[i + 1][0]):
			return lerpf(float(c[i][1]), float(c[i + 1][1]), inverse_lerp(float(c[i][0]), float(c[i + 1][0]), z))
	return float(c[-1][1]) if z > 0.0 else float(c[0][1])


## Altura da faixa da cintura: na cabine logo abaixo do vidro, caindo de leve
## pelo capô até o meio da grade.
static func _cintura(z: float) -> float:
	return 1.09 if z < 0.30 else lerpf(1.09, 1.04, inverse_lerp(0.30, 1.30, z))


# --- rodas --------------------------------------------------------------------

## Roda de raios de arame (malha guardada por modelo e lado).
static func roda_malha(modelo: String, lado: float) -> ArrayMesh:
	var chave := "%s|%d" % [modelo, 1 if lado >= 0.0 else -1]
	if not _rodas.has(chave):
		var m := MontagemMalha.new()
		_roda(m, MODELOS[modelo], 1.0 if lado >= 0.0 else -1.0)
		_rodas[chave] = CarroBloco.suavizar_por_angulo(m.malha(), 30.0, true)
	return _rodas[chave]


static func _roda(m: MontagemMalha, f: Dictionary, lado: float) -> void:
	_roda_em(m, f, Transform3D(Basis.from_scale(Vector3(lado, 1, 1)), Vector3.ZERO), lado)


## A roda em `xf` (eixo de giro em X): pneu alto e fino de flanco arredondado,
## aro, raios de arame cruzados e a calota pequena.
static func _roda_em(m: MontagemMalha, f: Dictionary, xf: Transform3D, lado := 1.0) -> void:
	var r := float(f["r"])
	var aro := float(f["aro"])
	var larg := float(f["pneu"])
	var lados := 24
	# pneu: seção arredondada (6 pontos) girada em volta do eixo
	var perfil := [[aro * 0.98, -larg * 0.42], [r * 0.9, -larg * 0.5], [r * 0.985, -larg * 0.34], [r, 0.0],
			[r * 0.985, larg * 0.34], [r * 0.9, larg * 0.5], [aro * 0.98, larg * 0.42]]
	_torno(m, "pneu", perfil, lados, xf)
	# aro
	_torno(m, "raio", [[aro, -larg * 0.38], [aro * 1.02, 0.0], [aro, larg * 0.38], [aro * 0.94, larg * 0.3],
			[aro * 0.94, -larg * 0.3]], lados, xf, true)
	# raios: metade presa na face de fora do cubo, metade na de dentro, cruzados
	var n := int(f["raios"])
	var cubo := 0.085
	for i in n:
		var a := TAU * i / n
		var dentro := i % 2 == 0
		var x0 := (-0.045 if dentro else 0.045)
		var a0 := a + (0.25 if i % 4 < 2 else -0.25)
		var p0 := Vector3(x0, cubo * cos(a0), cubo * sin(a0))
		var p1 := Vector3(x0 * 0.3, aro * 0.95 * cos(a), aro * 0.95 * sin(a))
		_barra_xf(m, "raio", xf * p0, xf * p1, 0.0045)
	# cubo e calota
	_torno(m, "raio", [[0.0, -0.06], [cubo, -0.06], [cubo, 0.05], [0.0, 0.05]], 12, xf, true)
	_torno(m, "cromo", [[0.0, 0.05], [0.08, 0.05], [0.075, 0.085], [0.045, 0.105], [0.0, 0.11]], 12, xf)


## Sólido de revolução em volta do eixo X: perfil de pontos [raio, x].
static func _torno(m: MontagemMalha, estilo: String, perfil: Array, lados: int, xf: Transform3D, fechar := false) -> void:
	var pts := perfil.duplicate()
	if fechar:
		pts.append(perfil[0])
	for i in lados:
		var a0 := TAU * i / lados
		var a1 := TAU * (i + 1) / lados
		for k in pts.size() - 1:
			var p: Array = pts[k]
			var q: Array = pts[k + 1]
			var v := [Vector3(p[1], p[0] * cos(a0), p[0] * sin(a0)), Vector3(p[1], p[0] * cos(a1), p[0] * sin(a1)),
					Vector3(q[1], q[0] * cos(a1), q[0] * sin(a1)), Vector3(q[1], q[0] * cos(a0), q[0] * sin(a0))]
			# para fora do eixo (ou da ponta, nas tampas)
			var meio: Vector3 = (v[0] + v[1] + v[2] + v[3]) * 0.25
			# banda: para longe do eixo; anel plano: para longe do meio do perfil em X
			var dentro := Vector3(meio.x, 0, 0)
			if absf(float(q[0]) - float(p[0])) > absf(float(q[1]) - float(p[1])) * 2.0:
				dentro = Vector3(_centro_x(pts), meio.y, meio.z)
			var w := []
			for u in v:
				w.append(xf * u)
			_face(m, estilo, w, xf * dentro)


static func _centro_x(pts: Array) -> float:
	var s := 0.0
	for p in pts:
		s += float(p[1])
	return s / pts.size()


static func _barra_xf(m: MontagemMalha, estilo: String, a: Vector3, b: Vector3, raio: float) -> void:
	_barra(m, estilo, a, b, raio, 4)
