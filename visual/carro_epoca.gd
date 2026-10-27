class_name CarroEpoca
extends RefCounted
## Carros de época gerados em código (conversão máfia 1930–1950,
## docs/idle/conversao_mafia.md, 6), um estilo por divisão, cada um montado peça
## por peça como os carros eram construídos ("tipo" em MODELOS):
## - "1928": capô estreito entre para-lamas soltos, estribo, grade de radiador em
##   pé, faróis em tigela numa barra, estepe atrás, rodas de raios de arame;
## - "1940": capô comprido de proa em V, faróis nos para-lamas em gota, estribo
##   curto, para-brisa bipartido, traseira em gota, rodas de aço com calota;
## - "hotrod": cupê de 1932 rebaixado e sem para-lamas, motor à mostra, grade em
##   pé, caixas de roda recortadas, pneus de trás largos;
## - "1951": carroceria envelope rebaixada, laterais lisas com friso cromado,
##   rodas de trás meio cobertas, grade larga e para-choque maciço, faixa branca.
## Nenhum emblema nem nome de fábrica.
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
	## Cupê comercial de 1940 (Circuito Clandestino): entre-eixos de 2,84 m,
	## pneus aro 16", 1,68 m de altura. Corpo e cabine: [z, meia largura em
	## baixo, meia largura em cima, base, topo, raio de cima, raio de baixo].
	"cupe_1940": {
		"tipo": "1940", "eixos": [1.42, -1.42], "bitola": 1.45,
		"roda": {"tipo": "aco", "r": 0.356, "aro": 0.205, "pneu": 0.16},
		"corpo": [[-2.40, 0.40, 0.30, 0.50, 0.70, 0.12, 0.05], [-2.28, 0.60, 0.50, 0.44, 0.86, 0.20, 0.06],
			[-2.05, 0.72, 0.62, 0.42, 0.97, 0.24, 0.06], [-1.70, 0.78, 0.68, 0.42, 1.03, 0.22, 0.06],
			[-1.20, 0.80, 0.72, 0.42, 1.06, 0.16, 0.06], [-0.40, 0.80, 0.73, 0.42, 1.07, 0.12, 0.06],
			[0.40, 0.80, 0.73, 0.42, 1.07, 0.12, 0.06], [0.68, 0.74, 0.66, 0.45, 1.07, 0.14, 0.06],
			[0.95, 0.56, 0.48, 0.52, 1.05, 0.18, 0.05], [1.40, 0.44, 0.38, 0.55, 1.01, 0.18, 0.05],
			[1.80, 0.36, 0.30, 0.56, 0.96, 0.16, 0.05], [2.02, 0.30, 0.25, 0.56, 0.91, 0.14, 0.05]],
		"proa": [[2.02, 0.28, 0.23, 0.56, 0.90, 0.12, 0.04], [2.16, 0.16, 0.13, 0.57, 0.87, 0.08, 0.03],
			[2.27, 0.03, 0.025, 0.58, 0.82, 0.02, 0.01]],
		"cabine": [[-1.50, 0.70, 0.62, 1.03, 1.06, 0.03, 0.0], [-1.25, 0.72, 0.60, 1.03, 1.32, 0.14, 0.0],
			[-0.95, 0.73, 0.58, 1.03, 1.52, 0.18, 0.0], [-0.60, 0.73, 0.58, 1.03, 1.63, 0.18, 0.0],
			[-0.10, 0.73, 0.58, 1.03, 1.66, 0.17, 0.0], [0.25, 0.73, 0.58, 1.03, 1.63, 0.15, 0.0],
			[0.50, 0.72, 0.60, 1.03, 1.36, 0.10, 0.0], [0.62, 0.70, 0.62, 1.03, 1.08, 0.03, 0.0]],
		"janelas": [[[0.40, 1.11], [-0.50, 1.11], [-0.50, 1.55], [0.24, 1.55]],
			[[-0.62, 1.11], [-1.08, 1.11], [-0.96, 1.40], [-0.62, 1.53]]],
		"para_brisa": [0.56, 0.30, 1.10, 1.59, 0.08, true],
		"vigia": [-1.30, -1.00, 1.12, 1.47, 0.22],
		"paralama_frente": [[2.20, 0.56, 0.04], [2.08, 0.72, 0.09], [1.90, 0.84, 0.12], [1.62, 0.92, 0.13],
			[1.40, 0.94, 0.13], [1.15, 0.88, 0.12], [0.95, 0.74, 0.09], [0.80, 0.56, 0.05], [0.62, 0.44, 0.01]],
		"estribo": [0.62, -0.92, 0.43],
		"paralama_tras": [[-0.92, 0.44, 0.01], [-1.02, 0.58, 0.06], [-1.12, 0.76, 0.11], [-1.30, 0.88, 0.13],
			[-1.52, 0.90, 0.13], [-1.76, 0.83, 0.12], [-1.98, 0.68, 0.09], [-2.12, 0.54, 0.04]],
		"paralama_largura": [0.58, 0.96], "paralama_saia": 0.16, "paralama_estilo": "pintura",
		"paralama_cheio": [[1.78, 2.20, 0.46], [-2.12, -1.86, 0.44]],
		"farol": {"z": 2.19, "x": 0.77, "y": 0.64, "r": 0.10},
		"para_choque": {"frente": 2.34, "tras": -2.48, "meia": 0.86, "y": 0.42},
		"portas": [0.56, -0.56],
	},
	## Hot rod de 1932 (Liga dos Hot Rods): cupê de três janelas com teto
	## rebaixado, sem para-lamas nem capô, motor V8 à mostra, eixo dianteiro
	## rebaixado; entre-eixos de 2,69 m, pneus de trás largos.
	"hotrod_1932": {
		"tipo": "hotrod", "eixos": [1.42, -1.27], "bitola": 1.36, "bitola_tras": 1.42,
		"roda": {"tipo": "cromada", "r": 0.33, "aro": 0.19, "pneu": 0.13},
		"roda_tras": {"tipo": "cromada", "r": 0.40, "aro": 0.20, "pneu": 0.26},
		"corpo": [[-1.85, 0.52, 0.40, 0.55, 0.78, 0.16, 0.04], [-1.70, 0.64, 0.54, 0.52, 0.95, 0.20, 0.04],
			[-1.30, 0.69, 0.60, 0.52, 1.03, 0.16, 0.04], [-0.60, 0.70, 0.62, 0.52, 1.06, 0.10, 0.04],
			[0.10, 0.70, 0.62, 0.52, 1.07, 0.08, 0.04], [0.25, 0.62, 0.55, 0.56, 1.08, 0.10, 0.04],
			[0.32, 0.50, 0.45, 0.60, 1.06, 0.12, 0.04]],
		"arcos": [[-1.27, 0.40, 0.09, 9.0]],
		"cabine": [[-0.95, 0.66, 0.60, 1.04, 1.40, 0.10, 0.0], [-0.75, 0.68, 0.60, 1.04, 1.44, 0.12, 0.0],
			[0.00, 0.68, 0.60, 1.04, 1.45, 0.10, 0.0], [0.20, 0.66, 0.60, 1.04, 1.42, 0.06, 0.0],
			[0.26, 0.64, 0.60, 1.04, 1.37, 0.03, 0.0]],
		"janelas": [[[0.17, 1.10], [-0.58, 1.10], [-0.58, 1.37], [0.16, 1.38]]],
		"para_brisa": [0.25, 0.21, 1.09, 1.36, 0.05, false],
		"vigia": [-0.93, -0.86, 1.12, 1.34, 0.26],
		"radiador": {"z": 1.30, "fundo": 0.08, "meia": 0.26, "base": 0.50, "topo": 1.08},
		"farol": {"z": 1.46, "x": 0.34, "y": 0.84, "r": 0.085},
		"portas": [0.20, -0.62],
	},
	## Sedã de 1951 (Stock Cars): carroceria envelope rebaixada (o piso abaixo
	## das longarinas), entre-eixos de 3,15 m, 1,53 m de altura, rodas de trás
	## meio cobertas pela saia, pneus de faixa branca.
	"seda_1951": {
		"tipo": "1951", "eixos": [1.575, -1.575], "bitola": 1.48,
		"roda": {"tipo": "faixa_branca", "r": 0.36, "aro": 0.19, "pneu": 0.18},
		"corpo": [[-2.62, 0.70, 0.60, 0.38, 0.72, 0.15, 0.08], [-2.50, 0.90, 0.80, 0.33, 0.86, 0.22, 0.10],
			[-2.20, 0.97, 0.88, 0.31, 0.93, 0.24, 0.10], [-1.60, 0.98, 0.90, 0.31, 0.95, 0.22, 0.10],
			[0.00, 0.98, 0.90, 0.31, 0.96, 0.20, 0.10], [1.60, 0.98, 0.90, 0.31, 0.96, 0.22, 0.10],
			[2.40, 0.96, 0.88, 0.33, 0.92, 0.22, 0.10], [2.60, 0.90, 0.82, 0.36, 0.86, 0.20, 0.10],
			[2.66, 0.84, 0.76, 0.40, 0.80, 0.16, 0.08]],
		"arcos": [[1.575, 0.36, 0.08, 9.0], [-1.575, 0.36, 0.08, 0.58]],
		"cabine": [[-1.45, 0.86, 0.70, 0.93, 0.97, 0.04, 0.0], [-1.15, 0.87, 0.70, 0.93, 1.25, 0.18, 0.0],
			[-0.80, 0.87, 0.68, 0.93, 1.45, 0.22, 0.0], [-0.40, 0.87, 0.68, 0.93, 1.53, 0.22, 0.0],
			[0.30, 0.87, 0.68, 0.93, 1.53, 0.20, 0.0], [0.60, 0.86, 0.70, 0.93, 1.40, 0.15, 0.0],
			[0.85, 0.84, 0.74, 0.93, 1.00, 0.04, 0.0]],
		"janelas": [[[0.66, 1.00], [-0.05, 1.00], [-0.05, 1.45], [0.47, 1.45]],
			[[-0.12, 1.00], [-0.88, 1.00], [-0.80, 1.36], [-0.12, 1.46]]],
		"para_brisa": [0.80, 0.52, 0.99, 1.46, 0.10, false],
		"vigia": [-1.24, -0.86, 1.00, 1.40, 0.16],
		"farol": {"z": 2.64, "x": 0.70, "y": 0.72, "r": 0.10},
		"para_choque": {"frente": 2.74, "tras": -2.70, "meia": 0.96, "y": 0.30},
		"portas": [0.70, -0.08, -0.90],
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
	for p in [["Mount_FrontLeft", -1.0, 0], ["Mount_FrontRight", 1.0, 0], ["Mount_RearLeft", -1.0, 1],
			["Mount_RearRight", 1.0, 1]]:
		var rd := _roda_spec(f, int(p[2]))
		var r := float(rd["r"])
		var meia := float(f.get("bitola_tras", f["bitola"]) if int(p[2]) == 1 else f["bitola"]) * 0.5
		var roda := MeshInstance3D.new()
		roda.name = String(p[0])
		roda.mesh = roda_malha(modelo, float(p[1]), int(p[2]))
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
	match String(f.get("tipo", "1928")):
		"1940":
			_montar_1940(m, f)
		"hotrod":
			_montar_hotrod(m, f)
		"1951":
			_montar_1951(m, f)
		_:
			_montar_1928(m, f)


static func _montar_1928(m: MontagemMalha, f: Dictionary) -> void:
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
			secoes.append(_secao_paralama(lado, float(larg[0]), float(larg[1]), Vector2(p[0], p[1]), n, float(p[2]),
					float(f.get("paralama_saia", 0.06))))
		_loft(m, String(f.get("paralama_estilo", "paralama")), secoes)
	# Estribo: tapete de borracha com friso.
	for lado: float in [-1.0, 1.0]:
		var x0 := lado * (float(larg[0]) + 0.02)
		var x1 := lado * (float(larg[1]) - 0.02)
		_bloco(m, "borracha", Vector3(minf(x0, x1), est[2] + 0.004, est[1] - 0.02), Vector3(maxf(x0, x1), est[2] + 0.012, est[0] + 0.02))
		_bloco(m, "cromo_epoca", Vector3(lado * float(larg[1]) - 0.008, est[2] - 0.02, est[1]), Vector3(lado * float(larg[1]) + 0.008, est[2] + 0.004, est[0]))


## Seção do para-lama: arco abaulado de dentro (x0) para fora (x1), espessura
## pequena; `n` é a normal do perfil (z, y) no ponto.
static func _secao_paralama(lado: float, x0: float, x1: float, o: Vector2, n: Vector2, abaulado: float,
		saia := 0.06) -> PackedVector3Array:
	var p := PackedVector3Array()
	var q := 8
	var esp := 0.025
	var cima := []
	for i in q + 1:
		var s := float(i) / q
		var h := abaulado * sin(PI * minf(s * 1.15, 1.0)) - (saia * pow(s, 6.0) if abaulado > 0.02 else 0.0)
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
	_loft(m, "cromo_epoca", [_secao(z0, meia, base, topo, 0.09), _secao(z1, meia, base, topo, 0.09)])
	# colmeia (um pouco para dentro da moldura)
	var zc := z1 + 0.002
	_painel_frente(m, "interno", zc, meia - 0.05, base + 0.06, topo - 0.07)
	var n := 13
	for i in n:
		var x := lerpf(-meia + 0.07, meia - 0.07, float(i) / (n - 1))
		_bloco(m, "aro_escuro", Vector3(x - 0.004, base + 0.06, zc), Vector3(x + 0.004, topo - 0.07, zc + 0.006))
	# tampa do radiador e enfeite
	_barra(m, "cromo_epoca", Vector3(0, topo - 0.01, z0 + 0.035), Vector3(0, topo + 0.05, z0 + 0.035), 0.035, 10)
	_barra(m, "cromo_epoca", Vector3(0, topo + 0.05, z0 + 0.035), Vector3(0, topo + 0.07, z0 + 0.07), 0.012, 6)
	# avental embaixo da grade
	_bloco(m, "paralama", Vector3(-meia + 0.02, 0.44, z0 - 0.02), Vector3(meia - 0.02, base, z1 - 0.01))


## Faróis em tigela cromada numa barra entre os para-lamas.
static func _farois(m: MontagemMalha, f: Dictionary) -> void:
	var fa: Dictionary = f["farol"]
	var z := float(fa["z"])
	var y := float(fa["y"])
	var r := float(fa["r"])
	_barra(m, "cromo_epoca", Vector3(-float(fa["x"]) - 0.08, y - r - 0.06, z - 0.03), Vector3(float(fa["x"]) + 0.08, y - r - 0.06, z - 0.03), 0.018, 8)
	for lado: float in [-1.0, 1.0]:
		var x := lado * float(fa["x"])
		# tigela: meia esfera virada para trás + aro e lente na frente
		m.esfera("cromo_epoca", r, r * 2.0, 12, 8, MontagemMalha.xf(Vector3(x, y, z - 0.02), Vector3(PI / 2, 0, 0), Vector3(1, 0.9, 1)))
		m.cilindro("cromo_epoca", r * 1.04, 0.03, 14, MontagemMalha.xf(Vector3(x, y, z + 0.06), Vector3(PI / 2, 0, 0)))
		m.cilindro("lente", r * 0.9, 0.012, 14, MontagemMalha.xf(Vector3(x, y, z + 0.08), Vector3(PI / 2, 0, 0)))
		# haste até a barra
		_barra(m, "preto", Vector3(x, y - r * 0.8, z - 0.02), Vector3(x, y - r - 0.06, z - 0.03), 0.014, 6)


## Para-choques de duas lâminas cromadas na frente; atrás, dois pedaços.
static func _para_choques(m: MontagemMalha, f: Dictionary) -> void:
	var zf := float(f["paralama_frente"][0][0]) + 0.10
	for y: float in [0.42, 0.53]:
		_bloco(m, "cromo_epoca", Vector3(-0.80, y - 0.022, zf - 0.012), Vector3(0.80, y + 0.022, zf + 0.012))
	for lado: float in [-1.0, 1.0]:
		# braçadeiras nas pontas e os braços até o chassi
		_bloco(m, "cromo_epoca", Vector3(lado * 0.74 - 0.02, 0.40, zf - 0.02), Vector3(lado * 0.74 + 0.02, 0.555, zf + 0.02))
		_barra(m, "preto", Vector3(lado * 0.42, 0.47, zf - 0.01), Vector3(lado * 0.42, 0.50, zf - 0.40), 0.018, 6)
	var zt := float(f["paralama_tras"][-1][0]) - 0.12
	for lado: float in [-1.0, 1.0]:
		for y: float in [0.44, 0.55]:
			_bloco(m, "cromo_epoca", Vector3(minf(lado * 0.36, lado * 0.80), y - 0.02, zt - 0.012),
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
		_bloco(m, "cromo_epoca", Vector3(minf(xp, xp + lado * 0.03), 1.04, float(f["portas"][1]) + 0.04),
				Vector3(maxf(xp, xp + lado * 0.03), 1.06, float(f["portas"][1]) + 0.13))
	# dobradiça do capô no meio
	_bloco(m, "cromo_epoca", Vector3(-0.012, 1.162, 0.34), Vector3(0.012, 1.175, 1.30))
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

## A roda do eixo (0 frente, 1 trás): a do modelo, ou "roda_tras" atrás. O
## cupê de 1928 guarda as medidas soltas (raios de arame).
static func _roda_spec(f: Dictionary, eixo: int) -> Dictionary:
	if f.has("roda"):
		return f["roda_tras"] if eixo == 1 and f.has("roda_tras") else f["roda"]
	return {"tipo": "arame", "r": f["r"], "aro": f["aro"], "pneu": f["pneu"], "raios": f["raios"]}


## A malha da roda (guardada por modelo, lado e eixo).
static func roda_malha(modelo: String, lado: float, eixo := 0) -> ArrayMesh:
	var chave := "%s|%d|%d" % [modelo, 1 if lado >= 0.0 else -1, eixo]
	if not _rodas.has(chave):
		var m := MontagemMalha.new()
		_roda(m, _roda_spec(MODELOS[modelo], eixo), 1.0 if lado >= 0.0 else -1.0)
		_rodas[chave] = CarroBloco.suavizar_por_angulo(m.malha(), 30.0, true)
	return _rodas[chave]


static func _roda(m: MontagemMalha, rd: Dictionary, lado: float) -> void:
	_roda_em(m, rd, Transform3D(Basis.from_scale(Vector3(lado, 1, 1)), Vector3.ZERO), lado)


## A roda em `xf` (eixo de giro em X): pneu alto e fino de flanco arredondado,
## aro, raios de arame cruzados e a calota pequena.
static func _roda_em(m: MontagemMalha, f: Dictionary, xf: Transform3D, lado := 1.0) -> void:
	if f.has("eixos"):
		f = _roda_spec(f, 0)
	var r := float(f["r"])
	var aro := float(f["aro"])
	var larg := float(f["pneu"])
	var lados := 24
	if String(f.get("tipo", "arame")) != "arame":
		_roda_disco(m, f, xf)
		return
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
	_torno(m, "cromo_epoca", [[0.0, 0.05], [0.08, 0.05], [0.075, 0.085], [0.045, 0.105], [0.0, 0.11]], 12, xf)


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


# --- peças dos estilos 1940, hot rod e 1951 -----------------------------------

## Seção arredondada com laterais inclinadas (meia largura `mb` embaixo e `mt`
## em cima), raio `r` nas quinas de cima e `rb` nas de baixo. Sempre 20 pontos.
static func _secao2(z: float, mb: float, mt: float, base: float, topo: float, r: float, rb: float) -> PackedVector3Array:
	var p := PackedVector3Array()
	r = minf(r, minf(mt, (topo - base) * 0.5) * 0.95)
	rb = minf(rb, minf(mb, (topo - base) * 0.5) * 0.95)
	var q := 4
	var cantos := [[Vector2(mb - rb, base + rb), rb, -PI * 0.5], [Vector2(mt - r, topo - r), r, 0.0],
			[Vector2(-mt + r, topo - r), r, PI * 0.5], [Vector2(-mb + rb, base + rb), rb, PI]]
	for c in cantos:
		for i in q + 1:
			var a: float = float(c[2]) + PI * 0.5 * i / q
			var o: Vector2 = c[0] + Vector2(cos(a), sin(a)) * float(c[1])
			p.append(Vector3(o.x, o.y, z))
	return p


## Linhas da tabela [z, mb, mt, base, topo, r, rb] reamostradas a cada `passo`
## m (curva suave), com as caixas de roda: em cada arco [z do eixo, raio da
## roda, folga, saia] a base sobe até o círculo da caixa (limitada pela saia).
static func _linhas(rows: Array, arcos: Array, passo := 0.06) -> Array:
	var densas := _suave(rows, 4)
	var out := []
	var z0 := float(densas[0][0])
	var z1 := float(densas[-1][0])
	var n := maxi(int((z1 - z0) / passo), 2)
	for k in n + 1:
		var z := lerpf(z0, z1, float(k) / n)
		var l := _linha_em(densas, z)
		for a in arcos:
			var dz := z - float(a[0])
			var raio := float(a[1]) + float(a[2])
			if absf(dz) < raio:
				var y := float(a[1]) + sqrt(raio * raio - dz * dz)
				l[3] = maxf(float(l[3]), minf(y, float(a[3])))
		out.append(l)
	return out


## A linha da tabela em z (interpolação linear entre as vizinhas).
static func _linha_em(rows: Array, z: float) -> Array:
	if z <= float(rows[0][0]):
		return rows[0].duplicate()
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if z <= float(b[0]):
			var t := inverse_lerp(float(a[0]), float(b[0]), z)
			var l := []
			for c in a.size():
				l.append(lerpf(float(a[c]), float(b[c]), t))
			l[0] = z
			return l
	return rows[-1].duplicate()


static func _loft_linhas(m: MontagemMalha, estilo: String, linhas: Array) -> void:
	var secoes := []
	for l in linhas:
		secoes.append(_secao2(l[0], l[1], l[2], l[3], l[4], l[5], l[6]))
	_loft(m, estilo, secoes)


## x da lateral na altura y da linha (a reta entre a base e o começo da quina).
static func _x_lado(l: Array, y: float) -> float:
	var t := clampf((y - float(l[3])) / maxf(float(l[4]) - float(l[5]) - float(l[3]), 0.01), 0.0, 1.0)
	return lerpf(float(l[1]), float(l[2]), t)


## Vidro (ou peça) desenhado sobre a lateral: polígono [z, y] projetado na
## superfície da tabela, `afasta` m para fora.
static func _sobre_lado(m: MontagemMalha, estilo: String, rows: Array, pol: Array, lado: float, afasta := 0.006) -> void:
	# Grade de 6 × 6 dentro do quadrilátero, cada ponto na superfície: o vidro
	# acompanha a curva da cabine (um plano só entrava nela no meio).
	var n := 6
	var g := []
	for i in n + 1:
		var linha := []
		for j in n + 1:
			var u := float(i) / n
			var w := float(j) / n
			var a: Vector2 = Vector2(pol[0][0], pol[0][1]).lerp(Vector2(pol[1][0], pol[1][1]), u)
			var b: Vector2 = Vector2(pol[3][0], pol[3][1]).lerp(Vector2(pol[2][0], pol[2][1]), u)
			var q := a.lerp(b, w)
			var l := _linha_em(rows, q.x)
			linha.append(Vector3(lado * (_x_lado(l, q.y) + afasta), q.y, q.x))
		g.append(linha)
	for i in n:
		for j in n:
			var v: Array = [g[i][j], g[i + 1][j], g[i + 1][j + 1], g[i][j + 1]]
			var c: Vector3 = (v[0] + v[2]) * 0.5
			_face(m, estilo, v, Vector3(0, c.y, c.z))


## Para-brisa (ou vigia) inclinado entre a borda de baixo (z0, y0) e a de cima
## (z1, y1), com `margem` das laterais; `meio` põe a coluna do centro. Em
## grade de 8 × 6, cada ponto assentado na curva de cima da cabine (um plano
## só ficava por baixo da lataria no meio e o vidro saía da cor do carro).
static func _vidro_inclinado(m: MontagemMalha, rows: Array, z0: float, z1: float, y0: float, y1: float, margem: float, meio := false) -> void:
	if absf(z1 - z0) < 0.12:
		# Vidro quase em pé (hot rod): fica na face da frente (ou de trás) da cabine.
		var ponta: Array = rows[-1] if z0 > 0.0 else rows[0]
		var zf := float(ponta[0]) + signf(z0) * 0.006
		var lb := _linha_em(rows, float(ponta[0]))
		var xb := _x_lado(lb, y0) - margem
		var xt := _x_lado(lb, y1) - margem
		var q := [Vector3(-xb, y0, zf), Vector3(xb, y0, zf), Vector3(xt, y1, zf), Vector3(-xt, y1, zf)]
		_face(m, "preto", q.map(func(p): return p + Vector3(signf(p.x) * 0.02, 0, -signf(z0) * 0.002)), Vector3(0, (y0 + y1) * 0.5, zf - signf(z0)))
		_face(m, "vidro_epoca", q, Vector3(0, (y0 + y1) * 0.5, zf - signf(z0)))
		return
	var nu := 8
	var nv := 6
	var g := []
	for j in nv + 1:
		var v := float(j) / nv
		var z := lerpf(z0, z1, v)
		var l := _linha_em(rows, z)
		var meia := maxf(_x_lado(l, lerpf(y0, y1, v)) - margem - float(l[5]) * 0.4 * v, 0.05)
		var linha := []
		for i in nu + 1:
			var x := lerpf(-meia, meia, float(i) / nu)
			linha.append(Vector3(x, _y_cima(l, x) + 0.008, z))
		g.append(linha)
	var dentro := Vector3(0, 0.5, (z0 + z1) * 0.5)
	for j in nv:
		for i in nu:
			_face(m, "vidro_epoca", [g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i]], dentro)
	if meio:
		for j in nv:
			var a: Vector3 = g[j][nu / 2] + Vector3(0, 0.006, 0)
			var b: Vector3 = g[j + 1][nu / 2] + Vector3(0, 0.006, 0)
			_face(m, "cromo_epoca", [a - Vector3(0.015, 0, 0), a + Vector3(0.015, 0, 0), b + Vector3(0.015, 0, 0),
					b - Vector3(0.015, 0, 0)], dentro)


## Altura da superfície de cima da linha em x (o teto e as quinas arredondadas).
static func _y_cima(l: Array, x: float) -> float:
	var mt := float(l[2])
	var topo := float(l[4])
	var r := minf(float(l[5]), minf(mt, (topo - float(l[3])) * 0.5) * 0.95)
	var ax := absf(x)
	if ax <= mt - r:
		return topo
	var dx := minf(ax - (mt - r), r)
	return topo - r + sqrt(maxf(r * r - dx * dx, 0.0))


## Cabine (estufa) de qualquer estilo: loft pintada, janelas laterais,
## para-brisa e vigia.
static func _estufa(m: MontagemMalha, f: Dictionary) -> void:
	var rows: Array = _linhas(f["cabine"], [], 0.05)
	_loft_linhas(m, MontagemMalha.PINTURA, rows)
	for lado: float in [-1.0, 1.0]:
		for pol in f["janelas"]:
			_sobre_lado(m, "preto", rows, _engordar(pol, 0.02), lado, 0.004)
			_sobre_lado(m, "vidro_epoca", rows, pol, lado, 0.007)
	var pb: Array = f["para_brisa"]
	_vidro_inclinado(m, rows, pb[0], pb[1], pb[2], pb[3], pb[4], bool(pb[5]))
	var vg: Array = f["vigia"]
	_vidro_inclinado(m, rows, vg[0], vg[1], vg[2], vg[3], vg[4])


## Polígono [z, y] alargado `d` para fora do centro (moldura).
static func _engordar(pol: Array, d: float) -> Array:
	var c := Vector2.ZERO
	for p in pol:
		c += Vector2(p[0], p[1])
	c /= pol.size()
	return pol.map(func(p): return [float(p[0]) + signf(float(p[0]) - c.x) * d, float(p[1]) + signf(float(p[1]) - c.y) * d])


## Caixas de roda escuras por dentro dos arcos (não se vê o outro lado).
static func _caixas(m: MontagemMalha, f: Dictionary) -> void:
	for a in f.get("arcos", []):
		var eixo := 0 if float(a[0]) > 0.0 else 1
		var rd := _roda_spec(f, eixo)
		var meia := float(f.get("bitola_tras", f["bitola"]) if eixo == 1 else f["bitola"]) * 0.5
		var dentro := meia - float(rd["pneu"]) * 0.5 - 0.03
		var raio := float(a[1]) + float(a[2])
		_bloco(m, "interno", Vector3(-dentro, 0.2, float(a[0]) - raio), Vector3(dentro, float(a[1]) + raio, float(a[0]) + raio))


## Para-choque de barra cromada arredondada com duas garras em pé.
static func _barra_choque(m: MontagemMalha, z: float, meia: float, y: float, alto: float, garras: bool) -> void:
	var sentido := signf(z)
	var pts := []
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-meia, meia, t)
		pts.append(Vector3(x, y, z - sentido * 0.22 * pow(absf(x) / meia, 3.0)))
	for i in pts.size() - 1:
		_barra(m, "cromo_epoca", pts[i], pts[i + 1], alto * 0.5, 10)
	if garras:
		for lado: float in [-1.0, 1.0]:
			_barra(m, "cromo_epoca", Vector3(lado * meia * 0.38, y - alto * 0.3, z + sentido * 0.03),
					Vector3(lado * meia * 0.38, y + alto * 1.9, z + sentido * 0.02), 0.035, 8)


## Farol redondo de aro cromado virado para a frente (ou inclinado `incl` rad).
static func _farol_redondo(m: MontagemMalha, c: Vector3, r: float, incl := 0.0, pintado := false) -> void:
	var rot := Vector3(PI / 2 - incl, 0, 0)
	if pintado:
		m.cilindro(MontagemMalha.PINTURA, r * 1.15, 0.22, 14, MontagemMalha.xf(c - Vector3(0, 0, 0.1), rot))
	m.cilindro("cromo_epoca", r * 1.05, 0.04, 16, MontagemMalha.xf(c, rot))
	m.cilindro("lente", r * 0.88, 0.02, 16, MontagemMalha.xf(c + Vector3(0, sin(incl) * 0.02, cos(incl) * 0.02), rot))


## 1940: corpo com capô comprido, proa em V com barras, grades laterais
## baixas, para-lamas em gota com os faróis em cima, estribo curto.
static func _montar_1940(m: MontagemMalha, f: Dictionary) -> void:
	_loft_linhas(m, MontagemMalha.PINTURA, _linhas(f["corpo"], []))
	_estufa(m, f)
	_paralamas(m, f)
	_paralamas_cheios(m, f)
	# Proa: cunha escura com barras cromadas em pé e o friso no alto.
	var proa: Array = f["proa"]
	_loft_linhas(m, "interno", _linhas(proa, [], 0.04))
	for lado: float in [-1.0, 1.0]:
		for i in 8:
			var t := (float(i) + 0.5) / 8.0
			var z := lerpf(float(proa[0][0]), float(proa[-1][0]), t)
			var l := _linha_em(proa, z)
			var x := lado * (lerpf(float(l[1]), float(l[2]), 0.5) + 0.004)
			_bloco(m, "cromo_epoca", Vector3(x - 0.006, float(l[3]) + 0.03, z - 0.008), Vector3(x + 0.006, float(l[4]) - 0.04, z + 0.008))
		# grades baixas dos lados da proa
		var zg := 2.06
		for k in 4:
			var y := 0.58 + k * 0.045
			_bloco(m, "cromo_epoca", Vector3(minf(lado * 0.30, lado * 0.52), y, zg - 0.01), Vector3(maxf(lado * 0.30, lado * 0.52), y + 0.018, zg + 0.01))
		_bloco(m, "interno", Vector3(minf(lado * 0.30, lado * 0.52), 0.56, zg - 0.03), Vector3(maxf(lado * 0.30, lado * 0.52), 0.75, zg - 0.01))
	_bloco(m, "cromo_epoca", Vector3(-0.012, 0.86, 1.0), Vector3(0.012, 0.92, 2.27))
	# Faróis nos para-lamas, inclinados com a curva.
	var fa: Dictionary = f["farol"]
	for lado: float in [-1.0, 1.0]:
		_farol_redondo(m, Vector3(lado * float(fa["x"]), float(fa["y"]), float(fa["z"])), float(fa["r"]), 0.45, true)
	var pc: Dictionary = f["para_choque"]
	_barra_choque(m, float(pc["frente"]), float(pc["meia"]), float(pc["y"]), 0.09, true)
	_barra_choque(m, float(pc["tras"]), float(pc["meia"]) * 0.95, float(pc["y"]) + 0.02, 0.08, true)
	# Lanternas nos para-lamas de trás, maçanetas, linhas das portas, chassi.
	for lado: float in [-1.0, 1.0]:
		m.cilindro("lanterna", 0.05, 0.05, 10, MontagemMalha.xf(Vector3(lado * 0.80, 0.80, -2.04), Vector3(PI / 2 + 0.6, 0, 0)))
		var l := _linha_em(f["corpo"], 0.0)
		var x := lado * (float(l[1]) + 0.004)
		for z in f["portas"]:
			_bloco(m, "interno", Vector3(minf(x, x + lado * 0.004), 0.48, float(z) - 0.004), Vector3(maxf(x, x + lado * 0.004), 1.04, float(z) + 0.004))
		_bloco(m, "cromo_epoca", Vector3(minf(x, x + lado * 0.03), 0.96, -0.50), Vector3(maxf(x, x + lado * 0.03), 0.98, -0.40))
	for z in f["eixos"]:
		_barra(m, "preto", Vector3(-0.6, 0.36, z), Vector3(0.6, 0.36, z), 0.035, 6)


## Frente e traseira maciças dos para-lamas em gota (na frente o farol assenta
## nela): lofts entre z0 e z1, do chão `base` até o topo do perfil do para-lama.
static func _paralamas_cheios(m: MontagemMalha, f: Dictionary) -> void:
	var larg: Array = f["paralama_largura"]
	var meio := (float(larg[0]) + float(larg[1])) * 0.5
	var meia := (float(larg[1]) - float(larg[0])) * 0.5
	for faixa in f.get("paralama_cheio", []):
		var perfil: Array = f["paralama_frente"] if float(faixa[0]) > 0.0 else f["paralama_tras"]
		var ordenado := perfil.duplicate()
		ordenado.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		var rows := []
		for k in 9:
			var z := lerpf(float(faixa[0]), float(faixa[1]), float(k) / 8.0)
			var l := _linha_em(ordenado, z)
			var topo := float(l[1]) + float(l[2]) - 0.02
			var ponta := sin(PI * float(k) / 8.0) if (k == 0 or k == 8) else 1.0
			var largura := meia * (0.55 + 0.45 * ponta) * (0.92 if (z > 0.0 and k == 8) or (z < 0.0 and k == 0) else 1.0)
			var base := float(faixa[2])
			rows.append([z, largura, largura * 0.82, base, maxf(topo, base + 0.06), minf(0.14, (topo - base) * 0.45), 0.04])
		for lado: float in [-1.0, 1.0]:
			var secoes := []
			for r in rows:
				var sec := _secao2(r[0], r[1], r[2], r[3], r[4], r[5], r[6])
				for i in sec.size():
					sec[i].x += lado * meio
				secoes.append(sec)
			_loft(m, String(f.get("paralama_estilo", "paralama")), secoes)


## Hot rod: corpo de 1932 em cima das longarinas, caixas de roda recortadas
## atrás, motor à mostra com tampas cromadas e escapes, grade em pé, faróis em
## bala numa barra, eixo da frente rebaixado e para-choques de tubo.
static func _montar_hotrod(m: MontagemMalha, f: Dictionary) -> void:
	_loft_linhas(m, MontagemMalha.PINTURA, _linhas(f["corpo"], f["arcos"]))
	_caixas(m, f)
	_estufa(m, f)
	# Longarinas da frente ao fundo, subindo sobre o eixo de trás.
	for lado: float in [-1.0, 1.0]:
		var x := lado * 0.36
		_bloco(m, "preto", Vector3(x - 0.04, 0.36, 0.2), Vector3(x + 0.04, 0.50, 1.55))
		_bloco(m, "preto", Vector3(x - 0.04, 0.42, -1.9), Vector3(x + 0.04, 0.54, 0.25))
	# Motor: bloco, tampas de válvula cromadas, compressor e três cornetas.
	_bloco(m, "aro_escuro", Vector3(-0.24, 0.48, 0.42), Vector3(0.24, 0.80, 1.20))
	for lado: float in [-1.0, 1.0]:
		var tampa := MontagemMalha.xf(Vector3(lado * 0.17, 0.86, 0.81), Vector3(0, 0, lado * 0.5))
		m.caixa("cromo_epoca", Vector3(0.14, 0.07, 0.74), tampa)
		# escapes: quatro tubos saindo do bloco e descendo para trás
		for k in 4:
			var z := 0.55 + k * 0.18
			var a := Vector3(lado * 0.25, 0.70, z)
			var b := Vector3(lado * 0.46, 0.62, z - 0.05)
			var c := Vector3(lado * 0.50, 0.40, z - 0.25)
			_barra(m, "cromo_epoca", a, b, 0.024, 8)
			_barra(m, "cromo_epoca", b, c, 0.024, 8)
		_barra(m, "cromo_epoca", Vector3(lado * 0.50, 0.38, 1.20), Vector3(lado * 0.52, 0.36, 0.0), 0.04, 8)
	_bloco(m, "cromo_epoca", Vector3(-0.13, 0.86, 0.62), Vector3(0.13, 1.00, 1.00))
	for k in 3:
		_barra(m, "cromo_epoca", Vector3(0, 1.0, 0.68 + k * 0.13), Vector3(0, 1.12, 0.68 + k * 0.13), 0.045, 10)
	# Grade do radiador em pé.
	var r: Dictionary = f["radiador"]
	var z0 := float(r["z"])
	var z1 := z0 + float(r["fundo"])
	var meia := float(r["meia"])
	_loft(m, MontagemMalha.PINTURA, [_secao2(z0, meia, meia * 0.92, float(r["base"]), float(r["topo"]), 0.12, 0.04),
			_secao2(z1, meia, meia * 0.92, float(r["base"]), float(r["topo"]), 0.12, 0.04)])
	_painel_frente(m, "interno", z1 + 0.002, meia - 0.05, float(r["base"]) + 0.05, float(r["topo"]) - 0.06)
	for i in 11:
		var x := lerpf(-meia + 0.07, meia - 0.07, float(i) / 10.0)
		_bloco(m, "cromo_epoca", Vector3(x - 0.005, float(r["base"]) + 0.05, z1), Vector3(x + 0.005, float(r["topo"]) - 0.06, z1 + 0.008))
	# Faróis em bala numa barra; eixo rebaixado e para-choques de tubo.
	var fa: Dictionary = f["farol"]
	_barra(m, "cromo_epoca", Vector3(-float(fa["x"]), 0.70, float(fa["z"]) - 0.06), Vector3(float(fa["x"]), 0.70, float(fa["z"]) - 0.06), 0.016, 8)
	for lado: float in [-1.0, 1.0]:
		var c := Vector3(lado * float(fa["x"]), float(fa["y"]), float(fa["z"]))
		m.esfera("cromo_epoca", float(fa["r"]), float(fa["r"]) * 2.4, 12, 8, MontagemMalha.xf(c - Vector3(0, 0, 0.04), Vector3(PI / 2, 0, 0)))
		m.cilindro("lente", float(fa["r"]) * 0.85, 0.02, 14, MontagemMalha.xf(c + Vector3(0, 0, 0.06), Vector3(PI / 2, 0, 0)))
		_barra(m, "cromo_epoca", c - Vector3(0, float(fa["r"]), 0.04), Vector3(lado * float(fa["x"]), 0.70, float(fa["z"]) - 0.06), 0.012, 6)
	var ze := float(f["eixos"][0])
	_barra(m, "cromo_epoca", Vector3(-0.62, 0.33, ze), Vector3(-0.3, 0.26, ze), 0.03, 8)
	_barra(m, "cromo_epoca", Vector3(-0.3, 0.26, ze), Vector3(0.3, 0.26, ze), 0.03, 8)
	_barra(m, "cromo_epoca", Vector3(0.3, 0.26, ze), Vector3(0.62, 0.33, ze), 0.03, 8)
	for zt: float in [1.62, -1.98]:
		_barra(m, "cromo_epoca", Vector3(-0.42, 0.44, zt), Vector3(0.42, 0.44, zt), 0.025, 8)
		for lado: float in [-1.0, 1.0]:
			_barra(m, "cromo_epoca", Vector3(lado * 0.30, 0.44, zt), Vector3(lado * 0.30, 0.62, zt), 0.02, 6)
			_barra(m, "cromo_epoca", Vector3(lado * 0.36, 0.46, zt), Vector3(lado * 0.36, 0.46, zt - signf(zt) * 0.2), 0.02, 6)
	for lado: float in [-1.0, 1.0]:
		m.cilindro("lanterna", 0.04, 0.04, 10, MontagemMalha.xf(Vector3(lado * 0.42, 0.70, -1.86), Vector3(PI / 2, 0, 0)))
		var l := _linha_em(f["corpo"], -0.2)
		var x := lado * (float(l[1]) + 0.004)
		for z in f["portas"]:
			_bloco(m, "interno", Vector3(minf(x, x + lado * 0.004), 0.56, float(z) - 0.004), Vector3(maxf(x, x + lado * 0.004), 1.04, float(z) + 0.004))


## 1951: carroceria envelope com as caixas de roda (a de trás com saia),
## cabine baixa, friso cromado de ponta a ponta, grade larga de barras
## deitadas, faróis nos cantos e para-choques maciços com garras.
static func _montar_1951(m: MontagemMalha, f: Dictionary) -> void:
	var rows := _linhas(f["corpo"], f["arcos"], 0.05)
	_loft_linhas(m, MontagemMalha.PINTURA, rows)
	_caixas(m, f)
	_estufa(m, f)
	var frente := float(f["corpo"][-1][0])
	# Grade: fundo escuro, barras deitadas e a moldura em V por cima.
	_painel_frente(m, "interno", frente + 0.004, 0.62, 0.46, 0.70)
	for k in 4:
		var y := 0.49 + k * 0.055
		_bloco(m, "cromo_epoca", Vector3(-0.60, y, frente), Vector3(0.60, y + 0.022, frente + 0.03))
	for lado: float in [-1.0, 1.0]:
		_barra(m, "cromo_epoca", Vector3(0, 0.76, frente + 0.03), Vector3(lado * 0.64, 0.70, frente + 0.02), 0.022, 8)
	var fa: Dictionary = f["farol"]
	for lado: float in [-1.0, 1.0]:
		_farol_redondo(m, Vector3(lado * float(fa["x"]), float(fa["y"]), float(fa["z"])), float(fa["r"]))
	var pc: Dictionary = f["para_choque"]
	_barra_choque(m, float(pc["frente"]), float(pc["meia"]), float(pc["y"]) + 0.07, 0.14, true)
	_barra_choque(m, float(pc["tras"]), float(pc["meia"]) * 0.96, float(pc["y"]) + 0.08, 0.12, true)
	# Friso cromado na lateral, lanternas, linhas das portas e maçanetas.
	for lado: float in [-1.0, 1.0]:
		var pts := []
		for i in 25:
			var z := lerpf(-2.40, 2.45, float(i) / 24.0)
			var l := _linha_em(rows, z)
			if float(l[3]) > 0.74:
				pts.append(null)
				continue
			pts.append(Vector3(lado * (_x_lado(l, 0.74) + 0.006), 0.74, z))
		for i in pts.size() - 1:
			if pts[i] != null and pts[i + 1] != null:
				_barra(m, "cromo_epoca", pts[i], pts[i + 1], 0.012, 6)
		_bloco(m, "lanterna", Vector3(lado * 0.80 - 0.05, 0.56, -2.62), Vector3(lado * 0.80 + 0.05, 0.80, -2.58))
		for z in f["portas"]:
			var l := _linha_em(rows, float(z))
			var x := lado * (_x_lado(l, 0.6) + 0.004)
			_bloco(m, "interno", Vector3(minf(x, x + lado * 0.004), 0.36, float(z) - 0.004), Vector3(maxf(x, x + lado * 0.004), 0.93, float(z) + 0.004))
		var lm := _linha_em(rows, 0.55)
		var xm := lado * (_x_lado(lm, 0.88) + 0.004)
		_bloco(m, "cromo_epoca", Vector3(minf(xm, xm + lado * 0.03), 0.87, 0.40), Vector3(maxf(xm, xm + lado * 0.03), 0.89, 0.52))
	_bloco(m, "cromo_epoca", Vector3(-0.012, 0.95, 1.2), Vector3(0.012, 0.975, 2.6))


## Rodas de disco: aço pintado com calota (1940), cromada (hot rod) ou com a
## faixa branca e a calota inteira (1951).
static func _roda_disco(m: MontagemMalha, rd: Dictionary, xf: Transform3D) -> void:
	var r := float(rd["r"])
	var aro := float(rd["aro"])
	var larg := float(rd["pneu"])
	var tipo := String(rd["tipo"])
	var perfil := [[aro * 0.98, -larg * 0.45], [r * 0.92, -larg * 0.5], [r * 0.99, -larg * 0.36], [r, 0.0],
			[r * 0.99, larg * 0.36], [r * 0.92, larg * 0.5], [aro * 0.98, larg * 0.45]]
	_torno(m, "pneu", perfil, 24, xf)
	if tipo == "faixa_branca":
		_torno(m, "re", [[aro * 1.12, larg * 0.505], [lerpf(aro, r, 0.62), larg * 0.505]], 24, xf)
	var face := larg * 0.42
	match tipo:
		"aco":
			_torno(m, "aro_roda_escuro", [[0.0, face - 0.02], [aro, face - 0.02], [aro, face + 0.01]], 20, xf)
			_torno(m, "cromo_epoca", [[aro * 0.98, face + 0.012], [aro * 1.04, face + 0.012]], 20, xf)
			_torno(m, "cromo_epoca", [[0.0, face + 0.07], [aro * 0.45, face + 0.06], [aro * 0.75, face + 0.025], [aro * 0.8, face]], 16, xf)
		"cromada":
			_torno(m, "cromo_epoca", [[0.0, face - 0.03], [aro, face - 0.03], [aro * 1.03, face + 0.01]], 20, xf)
			for k in 6:
				var a := TAU * k / 6.0
				var c := Vector3(face - 0.025, cos(a) * aro * 0.6, sin(a) * aro * 0.6)
				m.cilindro("interno", aro * 0.12, 0.012, 10, xf * MontagemMalha.xf(c, Vector3(0, 0, PI / 2)))
			_torno(m, "cromo_epoca", [[0.0, face + 0.03], [aro * 0.25, face + 0.02], [aro * 0.3, face - 0.02]], 12, xf)
		_:
			_torno(m, "cromo_epoca", [[0.0, face + 0.05], [aro * 0.5, face + 0.045], [aro * 0.95, face + 0.01], [aro * 1.02, face - 0.01]], 20, xf)
			_torno(m, "aro_roda_escuro", [[aro * 0.22, face + 0.052], [aro * 0.26, face + 0.052]], 16, xf)
