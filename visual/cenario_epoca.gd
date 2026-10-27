class_name CenarioEpoca
extends RefCounted
## Cenário de época das divisões da conversão máfia (docs/idle/conversao_mafia.md,
## 6): um autódromo rural do fim dos anos 1920 à tarde, em cores chapadas e
## poucas peças — pista de terra batida, cerca de madeira branca dos dois lados,
## gramado e plantações em volta, árvores, celeiro com silo, arquibancada de
## madeira coberta e a torre dos fiscais na largada, fardos de feno por fora das
## curvas e a largada quadriculada com a faixa de pano no alto. Sem zebra,
## brita, pneu empilhado, placa nem arquibancada moderna.
##
## Só a aparência: o traçado continua o da pista (a simulação e a força dos
## rivais por pista não mudam). Tudo numa malha só (cores por vértice).

## Apresentação, não balanceamento.
const CEU := Color(0.66, 0.72, 0.76)
const AMBIENTE := Color(0.74, 0.72, 0.66)
const LUZ := Color(1.0, 0.86, 0.66)
const GRAMA := Color(0.36, 0.42, 0.2)
const ACOSTAMENTO := Color(0.46, 0.46, 0.26)
const TERRA := Color(0.5, 0.36, 0.23)
const TERRA_BORDA := Color(0.44, 0.31, 0.2)
const CAMPOS := [Color(0.62, 0.52, 0.26), Color(0.3, 0.38, 0.16), Color(0.55, 0.4, 0.24), Color(0.44, 0.48, 0.2)]
const CERCA := Color(0.9, 0.88, 0.82)
const MADEIRA := Color(0.42, 0.29, 0.18)
const MADEIRA_CLARA := Color(0.62, 0.48, 0.32)
const VERMELHO := Color(0.56, 0.16, 0.13)
const CREME := Color(0.9, 0.85, 0.72)
const TELHADO := Color(0.24, 0.22, 0.21)
const FOLHAS := [Color(0.22, 0.32, 0.14), Color(0.27, 0.36, 0.16), Color(0.33, 0.38, 0.17)]
const FENO := Color(0.78, 0.64, 0.34)
const CERCA_M := 1.6  # da borda da pista à cerca
const POSTE_M := 3.0  # entre os mourões


## Monta o cenário em `cena`; ajusta céu e luz. `largura`: da pista (m).
const TERNOS := [Color("2b2b2e"), Color("3b3026"), Color("2a3346"), Color("4a4036"), Color("1f1f22"), Color("5b4a3a")]
const PELES := [Color("d9b08c"), Color("c69a74"), Color("a97a55"), Color("8a5d3b")]
const CHAPEUS := [Color("1c1a18"), Color("5a4a38"), Color("3a3a3a"), Color("c9b27a")]


static func montar(cena: Node3D, pista: Pista, largura: float, ambiente: Environment, luz: DirectionalLight3D) -> void:
	ambiente.background_color = CEU
	ambiente.ambient_light_color = AMBIENTE
	ambiente.fog_enabled = false
	luz.light_color = LUZ
	luz.light_energy = 1.15
	luz.rotation = Vector3(-0.75, 0.9, 0)
	var pts := pista.pontos(3.0)
	var amostra := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		amostra.append(pts[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pista.id + "|rural")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caixa := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		caixa = caixa.expand(p)
	_campos(st, rng, caixa, amostra, largura)
	_faixa(st, pts, -largura * 0.5 - 4.0, largura * 0.5 + 4.0, -0.02, ACOSTAMENTO)
	_faixa(st, pts, -largura * 0.5, largura * 0.5, 0.0, TERRA)
	for lado: float in [-1.0, 1.0]:
		_faixa(st, pts, lado * (largura * 0.5 - 1.4), lado * largura * 0.5, 0.005, TERRA_BORDA)
		_cerca(st, pts, lado * (largura * 0.5 + CERCA_M))
	_largada(st, pista, largura)
	var torre := _arquibancada(st, pista, amostra, largura)
	_fenos(st, pista, largura)
	_celeiro(st, rng, caixa, amostra, largura)
	_arvores(st, rng, pista, amostra, largura)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	cena.add_child(mi)
	_fumaca(cena, torre)


## Fumaça de charuto saindo da janela da torre dos fiscais (fiapos lentos).
static func _fumaca(cena: Node3D, onde: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = onde
	p.amount = 10
	p.lifetime = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 15.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0.15, 0.05, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.3))
	curva.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curva
	var esfera := SphereMesh.new()
	esfera.radius = 0.35
	esfera.height = 0.7
	esfera.radial_segments = 6
	esfera.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.83, 0.8, 0.22)
	esfera.material = m
	p.mesh = esfera
	cena.add_child(p)


# --- primitivas ---------------------------------------------------------------

## Quadrilátero com a cor, na ordem dada.
static func _quad(st: SurfaceTool, cor: Color, v: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(cor)
		st.add_vertex(v[idx])


## Quadrilátero (ou triângulo) com a face virada para `fora`.
static func _quad_para(st: SurfaceTool, cor: Color, v: Array, fora: Vector3) -> void:
	var n: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
	var w := v if n.dot(fora) <= 0.0 else ([v[0], v[3], v[2], v[1]] if v.size() > 3 else [v[0], v[2], v[1]])
	if w.size() > 3:
		_quad(st, cor, w)
	else:
		for q in w:
			st.set_color(cor)
			st.add_vertex(q)


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, -p.y)


## Faixa ao longo do traçado, de `de` a `ate` m do eixo (sinal = lado), na altura `y`.
static func _faixa(st: SurfaceTool, pts: PackedVector2Array, de: float, ate: float, y: float, cor: Color) -> void:
	var n := pts.size()
	for i in n - 1:
		var na := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
		var nb := (pts[mini(i + 2, n - 1)] - pts[i]).normalized().orthogonal()
		var v := [pts[i] + na * de, pts[i + 1] + nb * de, pts[i + 1] + nb * ate, pts[i] + na * ate]
		_quad_para(st, cor, v.map(func(p): return _v3(p, y)), Vector3.UP)


## Caixa orientada: centro no chão `p`, rumo, tamanho (frente, alto, fundo).
static func _caixa(st: SurfaceTool, cor: Color, p: Vector2, rumo: float, tam: Vector3, y0 := 0.0, topo := Color(0, 0, 0, 0)) -> void:
	var f := Vector2.from_angle(rumo) * tam.x * 0.5
	var l := Vector2.from_angle(rumo + PI / 2.0) * tam.z * 0.5
	var cantos := [p - f - l, p + f - l, p + f + l, p - f + l]
	var y1 := y0 + tam.y
	var centro := _v3(p, (y0 + y1) * 0.5)
	for k in 4:
		var a: Vector2 = cantos[k]
		var b: Vector2 = cantos[(k + 1) % 4]
		var v := [_v3(a, y0), _v3(b, y0), _v3(b, y1), _v3(a, y1)]
		_quad_para(st, cor, v, (v[0] + v[2]) * 0.5 - centro)
	_quad_para(st, topo if topo.a > 0.0 else cor.lightened(0.08), cantos.map(func(q): return _v3(q, y1)), Vector3.UP)


## Telhado de duas águas sobre a caixa (cumeeira ao longo do rumo).
static func _telhado(st: SurfaceTool, cor: Color, p: Vector2, rumo: float, tam: Vector2, y0: float, alto: float, oitao: Color) -> void:
	var f := Vector2.from_angle(rumo) * tam.x * 0.5
	var l := Vector2.from_angle(rumo + PI / 2.0) * tam.y * 0.5
	var cume := [_v3(p - f, y0 + alto), _v3(p + f, y0 + alto)]
	var centro := _v3(p, y0 + alto * 0.4)
	for s: float in [-1.0, 1.0]:
		var v := [_v3(p - f + l * s, y0), _v3(p + f + l * s, y0), cume[1], cume[0]]
		_quad_para(st, cor, v, (v[0] + v[2]) * 0.5 - centro)
	for s: float in [-1.0, 1.0]:
		var v := [_v3(p + f * s - l, y0), _v3(p + f * s + l, y0), cume[1] if s > 0.0 else cume[0]]
		_quad_para(st, oitao, v, _v3(f * s, 0.0))


## Copa de árvore facetada (octaedro achatado) sobre um tronco.
static func _arvore(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector2, escala: float) -> void:
	_caixa(st, MADEIRA, p, 0.0, Vector3(0.5, 2.4, 0.5) * escala)
	var cor: Color = FOLHAS[rng.randi() % FOLHAS.size()]
	var c := _v3(p, 4.4 * escala)
	var r := 2.6 * escala * rng.randf_range(0.85, 1.2)
	var h := 2.4 * escala
	var giro := rng.randf() * TAU
	var anel := []
	for k in 6:
		var a := giro + TAU * k / 6.0
		anel.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
	for k in 6:
		var a: Vector3 = anel[k]
		var b: Vector3 = anel[(k + 1) % 6]
		_quad_para(st, cor.lightened(0.06), [a, b, c + Vector3(0, h, 0)], (a + b) * 0.5 + Vector3(0, h, 0) - c)
		_quad_para(st, cor.darkened(0.15), [a, b, c - Vector3(0, h * 0.7, 0)], (a + b) * 0.5 - Vector3(0, h, 0) - c)


## Menor distância de `p` ao traçado.
static func _longe(p: Vector2, amostra: PackedVector2Array) -> float:
	var d := INF
	for q in amostra:
		d = minf(d, q.distance_to(p))
	return d


# --- peças --------------------------------------------------------------------

## Gramado e, mais longe, retalhos de plantação em faixas.
static func _campos(st: SurfaceTool, rng: RandomNumberGenerator, caixa: Rect2, amostra: PackedVector2Array, largura: float) -> void:
	var c := caixa.get_center()
	var meia := caixa.size * 0.5 + Vector2(500, 500)
	_quad_para(st, GRAMA, [_v3(c + Vector2(-meia.x, -meia.y), -0.06), _v3(c + Vector2(meia.x, -meia.y), -0.06),
			_v3(c + Vector2(meia.x, meia.y), -0.06), _v3(c + Vector2(-meia.x, meia.y), -0.06)], Vector3.UP)
	var lote := 60.0
	var x := c.x - meia.x
	while x < c.x + meia.x:
		var y := c.y - meia.y
		while y < c.y + meia.y:
			var centro := Vector2(x + lote * 0.5, y + lote * 0.5)
			if _longe(centro, amostra) > largura + lote * 0.75 and rng.randf() < 0.55:
				var cor: Color = CAMPOS[rng.randi() % CAMPOS.size()]
				var m := lote * 0.5 - 1.5
				_quad_para(st, cor, [_v3(centro + Vector2(-m, -m), -0.04), _v3(centro + Vector2(m, -m), -0.04),
						_v3(centro + Vector2(m, m), -0.04), _v3(centro + Vector2(-m, m), -0.04)], Vector3.UP)
				# sulcos da lavoura
				var sulco := -m + 3.0
				while sulco < m:
					_quad_para(st, cor.darkened(0.12), [_v3(centro + Vector2(sulco, -m), -0.035), _v3(centro + Vector2(sulco + 0.9, -m), -0.035),
							_v3(centro + Vector2(sulco + 0.9, m), -0.035), _v3(centro + Vector2(sulco, m), -0.035)], Vector3.UP)
					sulco += 4.0
			y += lote
		x += lote


## Cerca de madeira branca: mourões e duas tábuas, a `dist` m do eixo.
static func _cerca(st: SurfaceTool, pts: PackedVector2Array, dist: float) -> void:
	var n := pts.size()
	var desde := 0.0
	for i in n - 1:
		var na := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
		var nb := (pts[mini(i + 2, n - 1)] - pts[i]).normalized().orthogonal()
		var a := pts[i] + na * dist
		var b := pts[i + 1] + nb * dist
		for y: float in [0.55, 1.0]:
			var v := [_v3(a, y), _v3(b, y), _v3(b, y + 0.16), _v3(a, y + 0.16)]
			for s: float in [-1.0, 1.0]:
				_quad_para(st, CERCA, v, _v3(na * s, 0.0))
		desde += a.distance_to(b)
		if desde >= POSTE_M:
			desde = 0.0
			_caixa(st, CERCA.darkened(0.08), a, (b - a).angle(), Vector3(0.18, 1.3, 0.18))


## Fardos de feno empilhados por fora das curvas, junto à cerca.
static func _fenos(st: SurfaceTool, pista: Pista, largura: float) -> void:
	var s := 0.0
	while s < pista.comprimento:
		var t := pista.trecho_em(s)
		if float(t.get("raio_m", 0.0)) > 0.0:
			var fora := -1.0 if t.get("sentido", "esquerda") == "esquerda" else 1.0
			var rumo := pista.rumo_em(s)
			var p := pista.posicao_em(s) + Vector2.from_angle(rumo + PI / 2.0) * fora * (largura * 0.5 + 0.8)
			_caixa(st, FENO, p, rumo, Vector3(1.3, 0.6, 0.7), 0.0, FENO.lightened(0.12))
			if int(s / 3.0) % 2 == 0:
				_caixa(st, FENO.darkened(0.08), p, rumo, Vector3(1.3, 0.6, 0.7), 0.6, FENO.lightened(0.1))
		s += 3.0


## Largada quadriculada pintada na terra e a faixa de pano entre dois mastros.
static func _largada(st: SurfaceTool, pista: Pista, largura: float) -> void:
	var rumo := pista.rumo_em(0.0)
	var p := pista.posicao_em(0.0)
	var f := Vector2.from_angle(rumo)
	var l := Vector2.from_angle(rumo + PI / 2.0)
	var n := 12
	for i in n:
		for j in 2:
			var cor := Color(0.92, 0.9, 0.84) if (i + j) % 2 == 0 else Color(0.1, 0.09, 0.08)
			var a := p + l * (-largura * 0.5 + largura * i / n) + f * (j * 0.6 - 0.6)
			var v := [a, a + l * (largura / n), a + l * (largura / n) + f * 0.6, a + f * 0.6]
			_quad_para(st, cor, v.map(func(q): return _v3(q, 0.01)), Vector3.UP)
	for lado: float in [-1.0, 1.0]:
		_caixa(st, MADEIRA, p + l * lado * (largura * 0.5 + 0.8), rumo, Vector3(0.3, 7.5, 0.3))
	var a := p - l * (largura * 0.5 + 0.8)
	var b := p + l * (largura * 0.5 + 0.8)
	var pano := [_v3(a, 5.6), _v3(b, 5.6), _v3(b, 7.0), _v3(a, 7.0)]
	for s: float in [-1.0, 1.0]:
		_quad_para(st, CREME, pano, _v3(f * s, 0.0))
		var d := _v3(f * s * 0.02, 0.0)
		_quad_para(st, VERMELHO, [_v3(a, 5.75) + d, _v3(b, 5.75) + d, _v3(b, 5.95) + d, _v3(a, 5.95) + d], d)


## Arquibancada de madeira coberta por fora da reta da largada, com
## bandeirolas no telhado, e a torre dos fiscais do outro lado.
static func _arquibancada(st: SurfaceTool, pista: Pista, amostra: PackedVector2Array, largura: float) -> Vector3:
	var rumo := pista.rumo_em(0.0)
	var f := Vector2.from_angle(rumo)
	var l := Vector2.from_angle(rumo + PI / 2.0)
	# do lado de fora do circuito (o que tem mais espaço livre)
	var p0 := pista.posicao_em(0.0)
	if _longe(p0 - l * 30.0, amostra) > _longe(p0 + l * 30.0, amostra):
		l = -l
	var base := pista.posicao_em(-14.0) + l * (largura * 0.5 + CERCA_M + 2.5)
	var comp := 34.0
	for k in 5:  # degraus
		var p := base + l * (k * 1.6 + 0.8)
		_caixa(st, MADEIRA_CLARA if k % 2 == 0 else MADEIRA_CLARA.darkened(0.1), p, rumo, Vector3(comp, 0.6 + k * 0.7, 1.6))
	var fundo := base + l * 8.0
	_caixa(st, MADEIRA, fundo + l * 0.2, rumo, Vector3(comp, 6.4, 0.4))
	for k in 6:  # pilares
		var x := -comp * 0.5 + comp * k / 5.0
		_caixa(st, MADEIRA, base + f * x + l * 0.2, rumo, Vector3(0.3, 5.4, 0.3))
	var meio := base + l * 4.2
	_telhado(st, VERMELHO, meio, rumo, Vector2(comp + 1.0, 9.6), 5.4, 1.4, CREME)
	for k in 7:  # bandeirolas
		var x := -comp * 0.5 + comp * k / 6.0
		var q := meio + f * x
		_caixa(st, MADEIRA, q, rumo, Vector3(0.1, 2.2, 0.1), 6.8)
		var cor := VERMELHO if k % 2 == 0 else CREME
		_quad_para(st, cor, [_v3(q, 8.4), _v3(q + f * 1.1, 8.15), _v3(q, 7.8)], _v3(l, 0.0))
		_quad_para(st, cor, [_v3(q, 8.4), _v3(q + f * 1.1, 8.15), _v3(q, 7.8)], _v3(-l, 0.0))
	# torre dos fiscais, do outro lado, na linha
	var t := pista.posicao_em(4.0) - l * (largura * 0.5 + CERCA_M + 3.5)
	for dx: float in [-1.2, 1.2]:
		for dz: float in [-1.2, 1.2]:
			_caixa(st, MADEIRA, t + f * dx + l * dz, rumo, Vector3(0.25, 4.0, 0.25))
	_caixa(st, CREME, t, rumo, Vector3(3.2, 2.2, 3.2), 4.0)
	_caixa(st, Color(0.12, 0.11, 0.1), t + l * 1.62, rumo, Vector3(2.4, 0.9, 0.02), 5.0)
	_telhado(st, VERMELHO, t, rumo, Vector2(3.8, 3.8), 6.2, 1.2, CREME)
	_torcida(st, base, f, l, comp)
	_apostador(st, pista.posicao_em(-6.0) + l * (largura * 0.5 + CERCA_M + 1.4), rumo, l)
	return _v3(t + l * 1.8, 5.6)


## O público da arquibancada: ternos escuros, chapéus (fedora e palheta) e um
## ou outro lugar vazio, sentado em cada degrau.
static func _torcida(st: SurfaceTool, base: Vector2, f: Vector2, l: Vector2, comp: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1932
	var rumo := f.angle()
	for k in 5:
		var y := 0.6 + k * 0.7
		var n := 26
		for i in n:
			if rng.randf() < 0.15:
				continue  # lugar vazio
			var x := -comp * 0.5 + 0.8 + (comp - 1.6) * (i + rng.randf_range(-0.3, 0.3)) / (n - 1)
			var p := base + f * x + l * (k * 1.6 + 0.9)
			var terno: Color = TERNOS[rng.randi() % TERNOS.size()]
			_caixa(st, terno, p, rumo, Vector3(0.42, 0.55, 0.32), y)
			_caixa(st, PELES[rng.randi() % PELES.size()], p, rumo, Vector3(0.2, 0.22, 0.2), y + 0.58)
			if rng.randf() < 0.8:
				var chapeu: Color = CHAPEUS[rng.randi() % CHAPEUS.size()]
				_caixa(st, chapeu, p, rumo, Vector3(0.36, 0.035, 0.36), y + 0.78)
				_caixa(st, chapeu, p, rumo, Vector3(0.22, 0.12, 0.22), y + 0.8)


## O apostador encostado na cerca: de pé, de chapéu, com o quadro-negro das apostas.
static func _apostador(st: SurfaceTool, p: Vector2, rumo: float, l: Vector2) -> void:
	_caixa(st, Color("3a3026"), p, rumo, Vector3(0.48, 1.1, 0.34), 0.0)
	_caixa(st, Color("c69a74"), p, rumo, Vector3(0.22, 0.24, 0.22), 1.12)
	_caixa(st, Color("1c1a18"), p, rumo, Vector3(0.4, 0.04, 0.4), 1.36)
	_caixa(st, Color("1c1a18"), p, rumo, Vector3(0.24, 0.14, 0.24), 1.38)
	var q := p + Vector2.from_angle(rumo) * 1.0 + l * 0.2
	_caixa(st, MADEIRA, q, rumo, Vector3(0.08, 1.0, 0.08), 0.0)
	_caixa(st, Color("1e2a22"), q - l * 0.05, rumo, Vector3(1.1, 0.8, 0.05), 0.9)
	for k in 4:  # as linhas de giz das cotações
		_caixa(st, Color("e8e4da"), q - l * 0.09, rumo, Vector3(0.8, 0.04, 0.02), 1.05 + k * 0.15)


## Celeiro vermelho com silo, num canto do terreno longe da pista.
static func _celeiro(st: SurfaceTool, rng: RandomNumberGenerator, caixa: Rect2, amostra: PackedVector2Array, largura: float) -> void:
	for tentativa in 40:
		var p := caixa.get_center() + Vector2.from_angle(rng.randf() * TAU) * (caixa.size.length() * 0.5 + rng.randf_range(10.0, 50.0))
		if _longe(p, amostra) < largura + 30.0:
			continue
		var rumo := rng.randf() * TAU
		_caixa(st, VERMELHO, p, rumo, Vector3(16, 6, 11), 0.0)
		_telhado(st, TELHADO, p, rumo, Vector2(16.6, 11.6), 6.0, 4.0, VERMELHO)
		var porta := p + Vector2.from_angle(rumo) * 8.02
		_caixa(st, CREME, porta, rumo, Vector3(0.05, 4.2, 4.0), 0.0)
		var silo := p + Vector2.from_angle(rumo + PI / 2.0) * 9.0
		_caixa(st, Color(0.7, 0.68, 0.62), silo, rumo, Vector3(4.2, 12, 4.2), 0.0)
		_telhado(st, TELHADO, silo, rumo, Vector2(4.4, 4.4), 12.0, 1.6, TELHADO)
		return


## Árvores soltas e fileiras de quebra-vento pelo terreno, longe da pista.
static func _arvores(st: SurfaceTool, rng: RandomNumberGenerator, pista: Pista, amostra: PackedVector2Array, largura: float) -> void:
	var colocadas := 0
	for tentativa in 900:
		if colocadas >= maxi(90, int(pista.comprimento / 14.0)):
			break
		var s := rng.randf() * pista.comprimento
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var p := pista.posicao_em(s) + Vector2.from_angle(pista.rumo_em(s) + PI / 2.0) * lado * rng.randf_range(14.0, 80.0)
		if _longe(p, amostra) < largura * 0.5 + CERCA_M + 7.0:
			continue
		_arvore(st, rng, p, rng.randf_range(0.8, 1.35))
		colocadas += 1
