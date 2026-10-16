class_name TemasArena
extends RefCounted
## Cenário de cada arena em volta do bloco (data/arena.json → arenas[].tema;
## pedido do usuário: maquete com tema, como a referência da montanha com o
## riacho). Só tela: a simulação não vê nada disto. Cada tema ocupa o canto do
## bloco mais longe da estrada (e às vezes um lado), reserva o espaço para os
## pinheiros desviarem e pode afinar o pinheiral (pinheiro_fator). Malhas de
## caixa, cilindro e cone com cores lisas, como o resto da maquete.

const COR_ROCHA := Color(0.72, 0.45, 0.38)
const COR_ROCHA_ESCURA := Color(0.55, 0.32, 0.3)
const COR_NEVE := Color(0.95, 0.95, 0.97)
const COR_AGUA := Color(0.24, 0.72, 0.74, 0.82)
const COR_AGUA_ESCURA := Color(0.1, 0.2, 0.22, 0.9)
const COR_PEDRA := Color(0.74, 0.7, 0.62)
const COR_CONCRETO := Color(0.66, 0.66, 0.63)
const COR_FERRUGEM := [Color(0.5, 0.3, 0.2), Color(0.42, 0.36, 0.3), Color(0.36, 0.42, 0.46), Color(0.55, 0.25, 0.2),
		Color(0.5, 0.48, 0.35), Color(0.3, 0.32, 0.28)]
const CORES_CONTEINER := [Color(0.75, 0.22, 0.15), Color(0.15, 0.35, 0.62), Color(0.88, 0.5, 0.12),
		Color(0.2, 0.5, 0.3), Color(0.55, 0.55, 0.55), Color(0.85, 0.75, 0.2)]
const CORES_CARRO := [Color(0.8, 0.15, 0.12), Color(0.15, 0.3, 0.6), Color(0.9, 0.9, 0.88), Color(0.12, 0.12, 0.13),
		Color(0.6, 0.62, 0.65), Color(0.85, 0.6, 0.1), Color(0.2, 0.45, 0.25)]
const RIACHO_LARGURA_M := 3.2
const PICOS := 9
const PICO_ALTURA_M := [20.0, 44.0]  # do pé de fora ao do canto
const PICO_RAIO_M := [8.0, 14.0]
const NEVE_FRACAO := 0.62


static func montar(c: CenarioArena, tema: String) -> void:
	match tema:
		"montanha":
			_montanha(c)
		"pedreira":
			_pedreira(c)
		"docas":
			_docas(c)
		"ferro_velho":
			_ferro_velho(c)
		"galpao":
			_galpao(c)
		"fardos":
			_fardos(c)
		"fundicao":
			_fundicao(c)
		"estacionamento":
			_estacionamento(c)
		"lago":
			_lago(c)
		"claustro":
			_claustro(c)


# --- Apoio -------------------------------------------------------------------------

## Cantos do bloco do mais longe para o mais perto do fim da estrada:
## [{canto, e1, e2}], e1 e e2 ao longo dos dois lados que saem dele.
static func _cantos(c: CenarioArena) -> Array:
	var cantos := [c._mn, c._mn + Vector2(c._lado, 0), c._mn + Vector2(c._lado, c._lado), c._mn + Vector2(0, c._lado)]
	var centro := c._mn + Vector2.ONE * c._lado * 0.5
	var fim: Vector2 = c._estrada[1] if not c._estrada.is_empty() else centro + Vector2(0, -c._lado)
	var r := []
	for k in 4:
		var q: Vector2 = cantos[k]
		r.append({"canto": q, "e1": ((cantos[(k + 1) % 4] as Vector2) - q).normalized(),
				"e2": ((cantos[(k + 3) % 4] as Vector2) - q).normalized(), "d": q.distance_to(fim)})
	r.sort_custom(func(a, b): return a["d"] > b["d"])
	return r


## Escala nos eixos da própria base (a caixa unitária esticada depois de girada).
static func _esticar(b: Basis, s: Vector3) -> Basis:
	return Basis(b.x * s.x, b.y * s.y, b.z * s.z)


static func _ponto(z: Dictionary, t: float, s: float) -> Vector2:
	return z["canto"] + z["e1"] * t + z["e2"] * s


## Nó no chão em `q`, com a frente (−Z) para o centro do bloco (ou para `para`).
static func _no(c: CenarioArena, q: Vector2, para := Vector2.INF) -> Node3D:
	var centro := c._mn + Vector2.ONE * c._lado * 0.5
	var alvo: Vector2 = (centro - q) if para == Vector2.INF else para
	var no := Node3D.new()
	no.transform = Transform3D(Basis.looking_at(Vector3(alvo.x, 0, -alvo.y).normalized(), Vector3.UP), c._em(q))
	c.add_child(no)
	return no


## Tenta pôr algo de raio `raio` em (t, s) do canto; reserva e devolve o ponto,
## ou INF se não cabe (alambrado, estrada, arquibancada, borda, outro objeto).
static func _lugar(c: CenarioArena, z: Dictionary, t: float, s: float, raio: float) -> Vector2:
	var q := _ponto(z, t, s)
	if not c._livre(q, raio):
		return Vector2.INF
	c._reservas.append([q, raio])
	return q


static func _cilindro(pai: Node3D, r_baixo: float, r_cima: float, h: float, pos: Vector3, cor: Color, lados := 8,
		giro := Basis.IDENTITY) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.bottom_radius = r_baixo
	cil.top_radius = r_cima
	cil.height = h
	cil.radial_segments = lados
	cil.rings = 1
	m.mesh = cil
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.95
	m.material_override = mat
	m.transform = Transform3D(giro, pos)
	pai.add_child(m)
	return m


## Telhado de duas águas: prisma de largura x, altura h, comprimento z.
static func _telhado(pai: Node3D, tam: Vector3, pos: Vector3, cor: Color) -> void:
	var m := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = tam
	m.mesh = pr
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.95
	m.material_override = mat
	m.position = pos
	pai.add_child(m)


## Casco de carro velho: chassi e cabine, numa cor de ferrugem.
static func _carcaca(c: CenarioArena, pai: Node3D, pos: Vector3, giro: Basis, cor: Color) -> void:
	var no := Node3D.new()
	no.transform = Transform3D(giro, pos)
	pai.add_child(no)
	c._peca(no, Vector3(4.2, 0.85, 1.8), Vector3(0, 0.45, 0), cor)
	c._peca(no, Vector3(2.1, 0.65, 1.6), Vector3(-0.3, 1.2, 0), cor.darkened(0.15))


## Fumaça subindo da ponta (chaminé); sem ela em Efeitos leves.
static func _fumaca(pai: Node3D, pos: Vector3) -> void:
	if Preferencias.efeitos_leves:
		return
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 5.0
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.5
	p.gravity = Vector3(0.6, 0.15, 0)
	var cresce := Curve.new()
	cresce.add_point(Vector2(0, 0.5))
	cresce.add_point(Vector2(1, 2.5))
	p.scale_amount_curve = cresce
	var some := Gradient.new()
	some.set_color(0, Color(0.75, 0.74, 0.72, 0.55))
	some.set_color(1, Color(0.85, 0.84, 0.82, 0.0))
	p.color_ramp = some
	var mancha := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	mancha.gradient = g
	mancha.fill = GradientTexture2D.FILL_RADIAL
	mancha.fill_from = Vector2(0.5, 0.5)
	mancha.fill_to = Vector2(1.0, 0.5)
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	var m := StandardMaterial3D.new()
	m.albedo_texture = mancha
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	p.position = pos
	pai.add_child(p)


## Água: cor e transparência, com reflexos que correm (parada com Reduzir
## animações).
static func _material_agua(cor: Color) -> Material:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled;
uniform vec4 cor : source_color;
uniform float corre = 1.0;
void fragment() {
	float s = sin(UV.y * 18.0 - TIME * 3.0 * corre + sin(UV.x * 6.0 + UV.y * 3.0) * 1.5);
	ALBEDO = cor.rgb + vec3(0.12) * smoothstep(0.75, 1.0, s);
	ALPHA = cor.a;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("corre", 0.0 if Preferencias.reduzir_animacoes else 1.0)
	return m


## Espelho d'água num polígono (2D), na altura do chão + dy.
static func _espelho(c: CenarioArena, pontos: Array, cor: Color, dy := 0.05) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var meio := Vector2.ZERO
	for q in pontos:
		meio += q / pontos.size()
	var h := c._forma.altura(meio) + dy
	for i in pontos.size():
		var a: Vector2 = pontos[i]
		var b: Vector2 = pontos[(i + 1) % pontos.size()]
		for q in [meio, b, a]:
			st.set_uv(Vector2(q.x, q.y) * 0.08)
			st.add_vertex(Vector3(q.x, h, -q.y))
	st.generate_normals()
	var mi := c._malha(st.commit(), _material_agua(cor))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Pedras em volta de `q` (as do lote padrão do cenário).
static func _pedras_em(c: CenarioArena, pontos: Array, escala := 1.0) -> void:
	var xs := []
	var cores := []
	for q in pontos:
		var esc := Vector3(c._rng.randf_range(0.5, 1.2), c._rng.randf_range(0.35, 0.8), c._rng.randf_range(0.5, 1.2)) * escala
		xs.append(Transform3D(Basis(Vector3.UP, c._rng.randf() * TAU).scaled(esc), c._em(q, 0.05)))
		var g := c._rng.randf_range(0.52, 0.66)
		cores.append(Color(g, g, g * 0.96))
	var esfera := SphereMesh.new()
	esfera.radius = 0.9
	esfera.height = 1.8
	esfera.radial_segments = 6
	esfera.rings = 3
	c._lote(esfera, xs, cores)


# --- Montanha (Cratera do Vale) ------------------------------------------------------

## Montanhas facetadas com neve no canto mais longe da estrada (os dois lados
## dele) e um riacho que nasce no pé delas, desce até a borda e cai pela
## lateral do bloco num poço de água à vista (como no corte da maquete).
static func _montanha(c: CenarioArena) -> void:
	var z: Dictionary = _cantos(c)[0]
	var centro := c._mn + Vector2.ONE * c._lado * 0.5
	c.direcao_fundo = ((z["canto"] as Vector2) - centro).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ultimo_pe: Vector2 = z["canto"]
	var diag: Vector2 = ((z["e1"] as Vector2) + (z["e2"] as Vector2)).normalized()
	for p in PICOS:
		var ao_longo: Vector2 = z["e1"] if p % 2 == 0 else z["e2"]
		var t := 4.0 + float(p / 2) * 11.0 + c._rng.randf_range(-2.0, 2.0)
		var q: Vector2 = z["canto"] + ao_longo * t + diag * c._rng.randf_range(3.0, 8.0)
		var u := clampf(t / 50.0, 0.0, 1.0)
		var raio := lerpf(PICO_RAIO_M[1], PICO_RAIO_M[0], u) * c._rng.randf_range(0.85, 1.15)
		# Não invade o alambrado nem a borda do bloco.
		raio = minf(raio, -float(c._forma.muro_perto(q)[0]) - CenarioArena.ALAMBRADO_RECUO_M - 2.0)
		raio = minf(raio, minf(minf(q.x - c._mn.x, q.y - c._mn.y), minf(c._mn.x + c._lado - q.x, c._mn.y + c._lado - q.y)) + 3.0)
		if raio < 4.0:
			continue
		var altura := lerpf(PICO_ALTURA_M[1], PICO_ALTURA_M[0], u) * c._rng.randf_range(0.85, 1.1) * raio / PICO_RAIO_M[1]
		_pico(c, st, q, raio, altura)
		c._reservas.append([q, raio + 1.0])
		if p % 2 == 0:
			ultimo_pe = q + (z["e1"] as Vector2) * (raio + 1.5)
	st.generate_normals()
	c._malha(st.commit(), c._material(Color.WHITE, true))
	_riacho(c, ultimo_pe, z["e1"], z["e2"])


## Pico: base em 7 pontos com raio irregular, um anel no meio torto e a ponta
## deslocada; cada triângulo com a sua cor (facetado), neve no alto.
static func _pico(c: CenarioArena, st: SurfaceTool, q: Vector2, raio: float, altura: float) -> void:
	var lados := 7
	var chao := c._forma.altura(q) - 1.0
	var base := []
	var meio := []
	var giro := c._rng.randf() * TAU
	for i in lados:
		var a := giro + TAU * i / lados
		var rb := raio * c._rng.randf_range(0.8, 1.15)
		base.append(Vector3(q.x + cos(a) * rb, chao, -(q.y + sin(a) * rb)))
		var rm := raio * c._rng.randf_range(0.42, 0.6)
		meio.append(Vector3(q.x + cos(a + 0.2) * rm, chao + altura * c._rng.randf_range(0.42, 0.55), -(q.y + sin(a + 0.2) * rm)))
	var topo := Vector3(q.x + c._rng.randf_range(-1.0, 1.0), chao + altura, -q.y + c._rng.randf_range(-1.0, 1.0))
	for i in lados:
		var j := (i + 1) % lados
		_tri_pico(c, st, [base[i], meio[i], base[j]], chao, altura)
		_tri_pico(c, st, [base[j], meio[i], meio[j]], chao, altura)
		_tri_pico(c, st, [meio[i], topo, meio[j]], chao, altura)


static func _tri_pico(c: CenarioArena, st: SurfaceTool, v: Array, chao: float, altura: float) -> void:
	var y := ((v[0] as Vector3).y + (v[1] as Vector3).y + (v[2] as Vector3).y) / 3.0
	var f := (y - chao) / altura
	var cor := COR_ROCHA.lerp(COR_ROCHA_ESCURA, c._rng.randf() * 0.6)
	if f > NEVE_FRACAO + c._rng.randf_range(-0.08, 0.08):
		cor = COR_NEVE
	for p in v:
		st.set_color(cor)
		st.add_vertex(p)


## Riacho: do pé da última montanha até a borda do bloco, serpenteando, com
## pedras nas margens; na borda, a queda pela lateral e o poço de água.
static func _riacho(c: CenarioArena, ini: Vector2, e1: Vector2, e2: Vector2) -> void:
	var para_fora := -e2
	var dist_borda := INF
	for eixo in 2:
		if absf(para_fora[eixo]) > 1e-4:
			var limite: float = c._mn[eixo] + (c._lado if para_fora[eixo] > 0.0 else 0.0)
			dist_borda = minf(dist_borda, (limite - ini[eixo]) / para_fora[eixo])
	if dist_borda <= 2.0 or dist_borda > 40.0:
		return
	var pontos := []
	var passos := int(dist_borda / 1.0)
	for s in passos + 1:
		var t := float(s) / passos
		var q := ini + para_fora * dist_borda * t + e1 * sin(t * PI * 1.6) * 2.5 * (1.0 - t)
		pontos.append(q)
		c._reservas.append([q, RIACHO_LARGURA_M])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var comp := 0.0
	for s in pontos.size() - 1:
		var a: Vector2 = pontos[s]
		var b: Vector2 = pontos[s + 1]
		var n := (b - a).normalized().orthogonal() * RIACHO_LARGURA_M * 0.5
		var v := [c._em(a - n, 0.08), c._em(b - n, 0.08), c._em(b + n, 0.08), c._em(a + n, 0.08)]
		var uv := [Vector2(0, comp), Vector2(0, comp + a.distance_to(b)), Vector2(1, comp + a.distance_to(b)), Vector2(1, comp)]
		comp += a.distance_to(b)
		for j in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[j] * Vector2(1, 0.25))
			st.add_vertex(v[j])
	# A queda: a fita continua descendo pela lateral do bloco.
	var borda: Vector2 = pontos.back()
	var nb := para_fora.orthogonal() * RIACHO_LARGURA_M * 0.5
	var topo := c._forma.altura(borda) + 0.08
	var fora3 := Vector3(para_fora.x, 0, -para_fora.y) * 0.15
	var queda := [Vector3(borda.x - nb.x, topo, -(borda.y - nb.y)) + fora3, Vector3(borda.x - nb.x, topo - 6.0, -(borda.y - nb.y)) + fora3 * 2.0,
			Vector3(borda.x + nb.x, topo - 6.0, -(borda.y + nb.y)) + fora3 * 2.0, Vector3(borda.x + nb.x, topo, -(borda.y + nb.y)) + fora3]
	for j in [0, 1, 2, 0, 2, 3]:
		st.set_uv(Vector2(1.0 if j in [2, 3] else 0.0, (comp + (6.0 if j in [1, 2] else 0.0)) * 0.25))
		st.add_vertex(queda[j])
	st.generate_normals()
	var mi := c._malha(st.commit(), _material_agua(COR_AGUA))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_poco(c, borda, para_fora, RIACHO_LARGURA_M + 2.0, topo - 4.0)
	var margens := []
	for s in range(0, pontos.size(), 2):
		var q: Vector2 = pontos[s]
		var n := ((pontos[mini(s + 1, pontos.size() - 1)] as Vector2) - q).normalized().orthogonal()
		for lado in [-1.0, 1.0]:
			if c._rng.randf() < 0.6:
				margens.append(q + n * lado * (RIACHO_LARGURA_M * 0.5 + c._rng.randf_range(0.2, 0.8)))
	_pedras_em(c, margens, 0.8)


## Água à vista no corte do bloco: caixa translúcida encostada na lateral, de
## `topo` até o fundo.
static func _poco(c: CenarioArena, borda: Vector2, para_fora: Vector2, largura: float, topo: float) -> void:
	var fundo := c._forma.altura(c._mn) - CenarioArena.BASE_FUNDO_M
	var altura := topo - fundo
	if altura <= 0.5:
		return
	var poco := MeshInstance3D.new()
	poco.mesh = c._caixa(Vector3(largura, altura, 3.0))
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(COR_AGUA.r, COR_AGUA.g, COR_AGUA.b, 0.55)
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.roughness = 0.1
	poco.material_override = mp
	poco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var centro := borda - para_fora * 1.45
	poco.transform = Transform3D(Basis.looking_at(Vector3(para_fora.x, 0, -para_fora.y), Vector3.UP),
			Vector3(centro.x, fundo + altura * 0.5, -centro.y))
	c.add_child(poco)


# --- Pedreira (Pátio da Pedreira) ------------------------------------------------------

## Bancadas de pedra em degraus no canto (em L, mais altas junto à borda), montes
## de brita e matacões; o caminhão basculante ao pé.
static func _pedreira(c: CenarioArena) -> void:
	var z: Dictionary = _cantos(c)[0]
	var centro := c._mn + Vector2.ONE * c._lado * 0.5
	c.direcao_fundo = ((z["canto"] as Vector2) - centro).normalized()
	c.pinheiro_fator = 0.7
	for degrau in 4:
		var recuo := 2.0 + degrau * 5.0
		var altura := 14.0 - degrau * 3.5
		var comp := 50.0 - degrau * 9.0
		var cor := Color(0.72, 0.6, 0.47).lerp(Color(0.58, 0.5, 0.43), float(degrau % 2))
		for eixo in 2:
			var ao_longo: Vector2 = z["e1"] if eixo == 0 else z["e2"]
			var de_lado: Vector2 = z["e2"] if eixo == 0 else z["e1"]
			# Corta a bancada onde ela encostaria no alambrado.
			var ate := comp
			while ate > 8.0 and not c._livre(z["canto"] + ao_longo * ate + de_lado * (recuo + 2.5), 2.5):
				ate -= 3.0
			if ate <= 8.0:
				continue
			var meio: Vector2 = z["canto"] + ao_longo * (ate * 0.5) + de_lado * (recuo + 2.5)
			var no := Node3D.new()
			var giro := Basis.looking_at(Vector3(de_lado.x, 0, -de_lado.y), Vector3.UP)
			no.transform = Transform3D(giro, c._em(meio, -0.5))
			c.add_child(no)
			c._peca(no, Vector3(ate, altura, 5.0), Vector3(0, altura * 0.5, 0), cor)
			for k in int(ate / 6.0):
				c._reservas.append([z["canto"] + ao_longo * (3.0 + k * 6.0) + de_lado * (recuo + 2.5), 3.5])
	var brita := [Color(0.6, 0.58, 0.55), Color(0.72, 0.6, 0.45), Color(0.5, 0.5, 0.5)]
	var montes := 0
	for tentativa in 40:
		if montes >= 6:
			break
		var q := _lugar(c, z, c._rng.randf_range(24.0, 60.0), c._rng.randf_range(20.0, 45.0), 4.5)
		if q == Vector2.INF:
			continue
		var no := _no(c, q)
		_cilindro(no, c._rng.randf_range(3.0, 4.5), 0.3, c._rng.randf_range(2.5, 4.0), Vector3(0, 1.4, 0),
				brita[montes % brita.size()], 7)
		montes += 1
	var q := _lugar(c, z, 30.0, 26.0, 6.0)
	if q != Vector2.INF:
		var no := _no(c, q)
		c._peca(no, Vector3(2.6, 2.4, 2.4), Vector3(0, 1.6, -3.0), Color(0.95, 0.75, 0.12))
		c._peca(no, Vector3(2.8, 1.6, 5.0), Vector3(0, 2.2, 1.0), Color(0.95, 0.75, 0.12), Basis(Vector3.RIGHT, 0.15))
	var matacoes := []
	for k in 14:
		var p := _ponto(z, c._rng.randf_range(10.0, 55.0), c._rng.randf_range(20.0, 40.0))
		if c._livre(p, 1.5):
			matacoes.append(p)
	_pedras_em(c, matacoes, 1.6)


# --- Docas (Fosso das Docas) ----------------------------------------------------

## Mar ao longo do lado do bloco mais longe da estrada, com o cais de concreto,
## o poço à vista no corte, um navio e o pórtico de contêineres; pilhas de
## contêineres coloridos no canto.
static func _docas(c: CenarioArena) -> void:
	c.pinheiro_fator = 0.35
	var z: Dictionary = _cantos(c)[0]
	var e1: Vector2 = z["e1"]
	var e2: Vector2 = z["e2"]
	# A faixa de mar ao longo do lado e1 (de canto a canto), largura até o alambrado.
	var largura := 12.0
	while largura > 5.0 and not _faixa_livre(c, z, largura):
		largura -= 1.0
	var a: Vector2 = z["canto"]
	var b: Vector2 = a + e1 * c._lado
	_espelho(c, [a, b, b + e2 * largura, a + e2 * largura], Color(0.2, 0.5, 0.62, 0.85), -0.3)
	for k in int(c._lado / 4.0):
		c._reservas.append([a + e1 * (2.0 + k * 4.0) + e2 * largura * 0.5, largura * 0.5 + 0.5])
	# Cais: meio-fio de concreto na beira e cabeços de amarração.
	var cais := Node3D.new()
	c.add_child(cais)
	var beira := a + e2 * (largura + 0.4)
	for k in int(c._lado / 6.0):
		var p: Vector2 = beira + e1 * (3.0 + k * 6.0)
		var no := _no(c, p, e2)
		c._peca(no, Vector3(6.0, 0.5, 0.8), Vector3(0, 0.15, 0), COR_CONCRETO)
		if k % 2 == 0:
			_cilindro(no, 0.22, 0.28, 0.6, Vector3(0, 0.6, 0.0), Color(0.15, 0.15, 0.15), 6)
	_poco_faixa(c, a, e1, e2, largura)
	# Navio: casco, convés e a ponte de comando.
	var navio := _no(c, a + e1 * c._lado * 0.62 + e2 * largura * 0.5, e1)
	navio.position.y -= 0.3
	c._peca(navio, Vector3(min(largura - 2.0, 7.0), 2.2, 26.0), Vector3(0, 0.6, 0), Color(0.2, 0.25, 0.3))
	c._peca(navio, Vector3(min(largura - 2.0, 7.0) - 0.4, 0.3, 25.0), Vector3(0, 1.85, 0), Color(0.6, 0.2, 0.15))
	c._peca(navio, Vector3(4.0, 3.5, 4.0), Vector3(0, 3.6, 9.0), Color(0.92, 0.92, 0.9))
	for k in 3:
		c._peca(navio, Vector3(2.4, 2.4, 6.0), Vector3(0, 3.1, -6.0 + k * 6.1), CORES_CONTEINER[k])
	# Pórtico: duas pernas em A no cais e a viga que avança sobre a água.
	var q := a + e1 * c._lado * 0.3 + e2 * (largura + 3.0)
	var portico := _no(c, q, e2)
	var laranja := Color(0.9, 0.42, 0.12)
	for x in [-3.5, 3.5]:
		c._peca(portico, Vector3(0.6, 16.0, 0.6), Vector3(x, 8.0, 2.0), laranja)
		c._peca(portico, Vector3(0.6, 16.0, 0.6), Vector3(x, 8.0, -2.0), laranja)
	c._peca(portico, Vector3(1.0, 1.2, largura + 12.0), Vector3(-3.5, 16.5, largura * 0.5 - 4.0), laranja)
	c._peca(portico, Vector3(1.0, 1.2, largura + 12.0), Vector3(3.5, 16.5, largura * 0.5 - 4.0), laranja)
	c._peca(portico, Vector3(8.0, 2.0, 3.0), Vector3(0, 15.0, 0), Color(0.85, 0.85, 0.82))
	c._reservas.append([q, 6.0])
	c.direcao_fundo = ((a + e1 * c._lado * 0.3) - (c._mn + Vector2.ONE * c._lado * 0.5)).normalized()
	# Pilhas de contêineres no canto, em fileiras.
	for fila in 4:
		for k in 6:
			var p := _lugar(c, z, 8.0 + k * 7.0, largura + 7.0 + fila * 3.4, 2.6)
			if p == Vector2.INF:
				continue
			var no := _no(c, p, e1)
			var andares := c._rng.randi_range(1, 3)
			for h in andares:
				c._peca(no, Vector3(2.4, 2.55, 6.0), Vector3(0, 1.3 + h * 2.6, 0),
						CORES_CONTEINER[c._rng.randi_range(0, CORES_CONTEINER.size() - 1)])


static func _faixa_livre(c: CenarioArena, z: Dictionary, largura: float) -> bool:
	for k in int(c._lado / 3.0):
		var q: Vector2 = z["canto"] + (z["e1"] as Vector2) * (1.5 + k * 3.0) + (z["e2"] as Vector2) * (largura + 3.0)
		if -float(c._forma.muro_perto(q)[0]) < CenarioArena.ALAMBRADO_RECUO_M + 1.0 or c._perto_da_estrada(q, 1.0):
			return false
	return true


## O mar à vista no corte: caixa translúcida ao longo do lado inteiro.
static func _poco_faixa(c: CenarioArena, a: Vector2, e1: Vector2, e2: Vector2, largura: float) -> void:
	var fundo := c._forma.altura(c._mn) - CenarioArena.BASE_FUNDO_M
	var topo := c._forma.altura(a) - 0.3
	var mar := MeshInstance3D.new()
	mar.mesh = c._caixa(Vector3(c._lado, topo - fundo, largura))
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.2, 0.5, 0.62, 0.6)
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.roughness = 0.1
	mar.material_override = mp
	mar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var meio := a + e1 * c._lado * 0.5 + e2 * (largura * 0.5 - 0.05)
	mar.transform = Transform3D(Basis.looking_at(Vector3(e2.x, 0, -e2.y), Vector3.UP), Vector3(meio.x, (topo + fundo) * 0.5, -meio.y))
	c.add_child(mar)


# --- Ferro-velho (Anel do Ferro-Velho) ----------------------------------------------

## Pilhas de carcaças enferrujadas no canto e espalhadas, montes de pneus e o
## guindaste com o eletroímã.
static func _ferro_velho(c: CenarioArena) -> void:
	c.pinheiro_fator = 0.5
	var z: Dictionary = _cantos(c)[0]
	for k in 60:
		var p := _lugar(c, z, c._rng.randf_range(4.0, 75.0), c._rng.randf_range(4.0, 40.0), 2.6)
		if p == Vector2.INF:
			continue
		var no := _no(c, p)
		var andares := c._rng.randi_range(1, 3)
		for h in andares:
			var giro := Basis(Vector3.UP, c._rng.randf_range(-0.4, 0.4)).rotated(Vector3.FORWARD, c._rng.randf_range(-0.12, 0.12))
			_carcaca(c, no, Vector3(0, h * 1.5, 0), giro, COR_FERRUGEM[c._rng.randi_range(0, COR_FERRUGEM.size() - 1)])
	for k in 5:
		var p := _lugar(c, z, c._rng.randf_range(10.0, 50.0), c._rng.randf_range(8.0, 35.0), 1.6)
		if p == Vector2.INF:
			continue
		var no := _no(c, p)
		for h in c._rng.randi_range(3, 6):
			_cilindro(no, 0.6, 0.6, 0.35, Vector3(c._rng.randf_range(-0.1, 0.1), 0.18 + h * 0.36, 0), Color(0.08, 0.08, 0.09), 10)
	var q := _lugar(c, z, 22.0, 22.0, 4.0)
	if q != Vector2.INF:
		var no := _no(c, q)
		var amarelo := Color(0.95, 0.72, 0.1)
		c._peca(no, Vector3(4.0, 2.6, 5.0), Vector3(0, 1.3, 0), amarelo)
		c._peca(no, Vector3(0.8, 0.8, 22.0), Vector3(0, 9.5, -8.0), amarelo, Basis(Vector3.RIGHT, 0.6))
		c._peca(no, Vector3(0.06, 6.0, 0.06), Vector3(0, 12.0, -17.0), Color(0.15, 0.15, 0.15))
		_cilindro(no, 1.6, 1.6, 0.6, Vector3(0, 8.8, -17.0), Color(0.25, 0.25, 0.27), 10)
		_carcaca(c, no, Vector3(0, 6.6, -17.0), Basis(Vector3.UP, 0.4), COR_FERRUGEM[0])
		c.direcao_fundo = (q - (c._mn + Vector2.ONE * c._lado * 0.5)).normalized()


# --- Galpão (Várzea do Galpão) -----------------------------------------------------

## O galpão vermelho com telhado de duas águas, o silo, a plantação em fileiras e
## a cerca de madeira: a várzea de interior.
static func _galpao(c: CenarioArena) -> void:
	var z: Dictionary = _cantos(c)[0]
	var q := _lugar(c, z, 18.0, 18.0, 10.0)
	if q != Vector2.INF:
		var no := _no(c, q)
		no.scale = Vector3.ONE * 1.35
		var vermelho := Color(0.62, 0.17, 0.13)
		c._peca(no, Vector3(14.0, 7.0, 11.0), Vector3(0, 3.5, 0), vermelho)
		# Cumeeira ao longo do comprimento (x): o prisma (ponta no meio de x) gira.
		_telhado(no, Vector3(11.6, 4.0, 15.0), Vector3(0, 9.0, 0), Color(0.35, 0.35, 0.37))
		(no.get_child(no.get_child_count() - 1) as Node3D).rotation.y = PI * 0.5
		c._peca(no, Vector3(4.0, 5.0, 0.12), Vector3(0, 2.5, -5.55), Color(0.92, 0.9, 0.85))
		c._peca(no, Vector3(3.4, 4.6, 0.14), Vector3(0, 2.4, -5.6), Color(0.45, 0.12, 0.1))
		c._peca(no, Vector3(0.18, 6.4, 0.16), Vector3(0, 2.4, -5.66), Color(0.92, 0.9, 0.85), Basis(Vector3.BACK, 0.62))
		c._peca(no, Vector3(0.18, 6.4, 0.16), Vector3(0, 2.4, -5.66), Color(0.92, 0.9, 0.85), Basis(Vector3.BACK, -0.62))
	var s := _lugar(c, z, 30.0, 8.0, 3.6)
	if s != Vector2.INF:
		var no := _no(c, s)
		_cilindro(no, 3.0, 3.0, 12.0, Vector3(0, 6.0, 0), Color(0.78, 0.78, 0.74), 12)
		_cilindro(no, 3.1, 0.4, 2.2, Vector3(0, 13.1, 0), Color(0.55, 0.57, 0.58), 12)
	# Plantação: fileiras verdes sobre terra arada, no outro canto longe da estrada.
	var z2: Dictionary = _cantos(c)[1]
	var plantas := []
	var terra := []
	for fila in 14:
		for k in 14:
			var p := _ponto(z2, 5.0 + k * 3.0, 4.0 + fila * 2.2)
			if not c._livre(p, 1.6):
				continue
			c._reservas.append([p, 1.5])
			var x := Transform3D(Basis.looking_at(Vector3((z2["e1"] as Vector2).x, 0, -(z2["e1"] as Vector2).y), Vector3.UP), c._em(p, 0.02))
			terra.append(Transform3D(_esticar(x.basis, Vector3(2.0, 0.08, 3.1)), x.origin))
			plantas.append(Transform3D(_esticar(x.basis, Vector3(0.6, 0.5, 3.0)), x.origin + Vector3.UP * 0.25))
	c._lote(c._caixa(Vector3.ONE), terra, [], c._material(Color(0.45, 0.32, 0.22)))
	c._lote(c._caixa(Vector3.ONE), plantas, [], c._material(Color(0.4, 0.62, 0.25)))


# --- Fardos (Curral dos Fardos) -------------------------------------------------

## Fardos redondos de feno empilhados e espalhados, o cata-vento (gira) e a caixa
## d'água: a fazenda do curral.
static func _fardos(c: CenarioArena) -> void:
	var z: Dictionary = _cantos(c)[0]
	var feno := Color(0.86, 0.72, 0.35)
	var deitado := Basis(Vector3.FORWARD, PI * 0.5)
	for k in 20:
		var p := _lugar(c, z, c._rng.randf_range(5.0, 70.0), c._rng.randf_range(5.0, 40.0), 2.8)
		if p == Vector2.INF:
			continue
		var no := _no(c, p)
		var pilha := c._rng.randi_range(1, 3)
		for b in pilha:
			_cilindro(no, 0.8, 0.8, 1.3, Vector3(-0.85 + b * 1.7 if b < 2 else 0.0, 0.8 if b < 2 else 2.2, 0), feno, 10, deitado)
	var espalhados := []
	for k in 60:
		var p := c._mn + Vector2(c._rng.randf(), c._rng.randf()) * c._lado
		if c._livre(p, 1.2):
			c._reservas.append([p, 1.2])
			espalhados.append(Transform3D(Basis(Vector3.UP, c._rng.randf() * TAU) * deitado, c._em(p, 0.8)))
	var cil := CylinderMesh.new()
	cil.top_radius = 0.8
	cil.bottom_radius = 0.8
	cil.height = 1.3
	cil.radial_segments = 10
	c._lote(cil, espalhados, [], c._material(feno))
	var q := _lugar(c, z, 22.0, 22.0, 3.0)
	if q != Vector2.INF:
		var no := _no(c, q)
		var aco := Color(0.55, 0.55, 0.52)
		for x in [-1.2, 1.2]:
			for zz in [-1.2, 1.2]:
				c._peca(no, Vector3(0.15, 11.0, 0.15), Vector3(x * 0.6, 5.5, zz * 0.6), aco,
						Basis(Vector3.FORWARD, -x * 0.05).rotated(Vector3.RIGHT, zz * 0.05))
		var helice := Node3D.new()
		helice.set_meta("animado", true)  # gira: fica fora da malha fundida
		helice.position = Vector3(0, 11.2, -0.8)
		no.add_child(helice)
		for k in 12:
			c._peca(helice, Vector3(0.35, 2.4, 0.04), Vector3(0, 1.2, 0).rotated(Vector3.BACK, TAU * k / 12.0),
					Color(0.85, 0.85, 0.82), Basis(Vector3.BACK, TAU * k / 12.0))
		c._peca(no, Vector3(0.1, 0.8, 2.2), Vector3(0, 11.2, 0.6), aco)
		if not Preferencias.reduzir_animacoes:
			var tw := c.create_tween().set_loops()
			tw.tween_property(helice, "rotation:z", TAU, 4.0).from(0.0)
	var t := _lugar(c, z, 34.0, 10.0, 3.0)
	if t != Vector2.INF:
		var no := _no(c, t)
		for x in [-1.0, 1.0]:
			for zz in [-1.0, 1.0]:
				c._peca(no, Vector3(0.2, 6.0, 0.2), Vector3(x, 3.0, zz), Color(0.42, 0.29, 0.19))
		_cilindro(no, 1.8, 1.8, 2.6, Vector3(0, 7.3, 0), Color(0.55, 0.4, 0.28), 10)
		_cilindro(no, 1.9, 0.2, 0.9, Vector3(0, 9.05, 0), Color(0.4, 0.3, 0.22), 10)


# --- Fundição (Pátio da Fundição) ------------------------------------------------

## O galpão da fundição com telhado em dentes de serra, chaminés listradas com
## fumaça, tanques e tubulação; pouco verde.
static func _fundicao(c: CenarioArena) -> void:
	c.pinheiro_fator = 0.3
	var z: Dictionary = _cantos(c)[0]
	var centro := c._mn + Vector2.ONE * c._lado * 0.5
	c.direcao_fundo = ((z["canto"] as Vector2) - centro).normalized()
	var q := _lugar(c, z, 20.0, 12.0, 11.0)
	if q != Vector2.INF:
		var no := _no(c, q)
		c._peca(no, Vector3(26.0, 9.0, 14.0), Vector3(0, 4.5, 0), Color(0.5, 0.52, 0.53))
		for k in 5:
			c._peca(no, Vector3(5.2, 2.2, 14.0), Vector3(-10.4 + k * 5.2, 9.9, 0), Color(0.4, 0.42, 0.44),
					Basis(Vector3.FORWARD, 0.35))
		for k in 4:
			c._peca(no, Vector3(3.0, 4.0, 0.1), Vector3(-9.0 + k * 6.0, 2.5, -7.05), Color(0.25, 0.27, 0.3))
	for k in 3:
		var p := _lugar(c, z, 6.0 + k * 9.0, 30.0 - k * 4.0, 2.2)
		if p == Vector2.INF:
			p = _lugar(c, z, 30.0 + k * 6.0, 4.0, 2.2)
		if p == Vector2.INF:
			continue
		var no := _no(c, p)
		var alt := 24.0 + k * 3.0
		for faixa in 6:
			_cilindro(no, 1.4 - faixa * 0.08, 1.4 - (faixa + 1) * 0.08, alt / 6.0, Vector3(0, alt / 6.0 * (faixa + 0.5), 0),
					Color(0.75, 0.2, 0.15) if faixa % 2 == 0 else Color(0.92, 0.92, 0.9), 10)
		_fumaca(no, Vector3(0, alt + 0.5, 0))
	for k in 3:
		var p := _lugar(c, z, 40.0 + k * 7.0, 14.0, 3.4)
		if p == Vector2.INF:
			continue
		var no := _no(c, p)
		_cilindro(no, 3.0, 3.0, 8.0, Vector3(0, 4.0, 0), Color(0.82, 0.82, 0.8), 12)
		_cilindro(no, 3.05, 0.6, 1.5, Vector3(0, 8.75, 0), Color(0.7, 0.7, 0.68), 12)
		c._peca(no, Vector3(0.5, 0.5, 7.0), Vector3(0, 6.0, -5.5), Color(0.6, 0.45, 0.2))


# --- Estacionamento (Estacionamento da Última Saída) ---------------------------------

## O pátio de asfalto com vagas pintadas e carros parados, os postes de luz e a
## placa da saída.
static func _estacionamento(c: CenarioArena) -> void:
	c.pinheiro_fator = 0.45
	var z: Dictionary = _cantos(c)[0]
	var e1: Vector2 = z["e1"]
	var e2: Vector2 = z["e2"]
	var vagas := []
	for fila in 5:
		for k in 18:
			var p := _ponto(z, 4.0 + k * 3.0, 5.0 + fila * 7.0)
			if c._livre(p, 2.0):
				vagas.append(p)
	if vagas.is_empty():
		return
	var giro := Basis.looking_at(Vector3(e2.x, 0, -e2.y), Vector3.UP)
	var asfalto := []
	var linhas := []
	for p in vagas:
		c._reservas.append([p, 2.0])
		var o := c._em(p, 0.03)
		asfalto.append(Transform3D(_esticar(giro, Vector3(3.0, 0.06, 7.0)), o))
		linhas.append(Transform3D(_esticar(giro, Vector3(0.12, 0.07, 5.0)), o + giro.x * 1.5))
	c._lote(c._caixa(Vector3.ONE), asfalto, [], c._material(Color(0.24, 0.24, 0.26)))
	c._lote(c._caixa(Vector3.ONE), linhas, [], c._material(Color(0.92, 0.92, 0.88)))
	for p in vagas:
		if c._rng.randf() < 0.6:
			var no := Node3D.new()
			no.transform = Transform3D(giro * Basis(Vector3.UP, PI * 0.5 + c._rng.randf_range(-0.08, 0.08)), c._em(p))
			c.add_child(no)
			var cor: Color = CORES_CARRO[c._rng.randi_range(0, CORES_CARRO.size() - 1)]
			c._peca(no, Vector3(4.2, 0.8, 1.8), Vector3(0, 0.55, 0), cor)
			c._peca(no, Vector3(2.2, 0.6, 1.6), Vector3(-0.3, 1.2, 0), Color(0.2, 0.25, 0.3))
	for k in 4:
		var p: Vector2 = vagas[mini(k * vagas.size() / 4, vagas.size() - 1)] + e2 * 3.5
		var no := _no(c, p)
		c._peca(no, Vector3(0.18, 8.0, 0.18), Vector3(0, 4.0, 0), Color(0.3, 0.32, 0.33))
		c._peca(no, Vector3(1.4, 0.3, 0.5), Vector3(0, 8.0, 0), Color(0.3, 0.32, 0.33))
	var q := _lugar(c, z, 46.0, 4.0, 3.0)
	if q != Vector2.INF:
		var no := _no(c, q)
		for x in [-2.5, 2.5]:
			c._peca(no, Vector3(0.3, 7.0, 0.3), Vector3(x, 3.5, 0), Color(0.3, 0.32, 0.33))
		c._peca(no, Vector3(7.0, 2.4, 0.2), Vector3(0, 6.2, 0), Color(0.12, 0.42, 0.25))
		var texto := Label3D.new()
		texto.text = "ÚLTIMA SAÍDA"
		texto.font_size = 96
		texto.pixel_size = 0.01
		texto.position = Vector3(0, 6.2, -0.12)
		texto.rotation.y = PI
		no.add_child(texto)


# --- Lago (Bacia de Blackwater) -----------------------------------------------------

## O lago escuro no canto, com juncos na beira, um píer de madeira com o barco
## e árvores secas em volta.
static func _lago(c: CenarioArena) -> void:
	var z: Dictionary = _cantos(c)[0]
	var centro := _ponto(z, 26.0, 24.0)
	var raio := 20.0
	while raio > 6.0 and not c._livre(centro, raio):
		raio -= 1.0
		centro = _ponto(z, 6.0 + raio, 6.0 + raio)
	if raio <= 6.0:
		return
	var pontos := []
	for k in 14:
		var a := TAU * k / 14.0
		pontos.append(centro + Vector2.from_angle(a) * raio * c._rng.randf_range(0.8, 1.05))
	_espelho(c, pontos, COR_AGUA_ESCURA, 0.04)
	c._reservas.append([centro, raio + 1.0])
	var juncos := []
	for k in 60:
		var a := c._rng.randf() * TAU
		var p := centro + Vector2.from_angle(a) * raio * c._rng.randf_range(0.85, 1.05)
		juncos.append(Transform3D(Basis(Vector3.UP, c._rng.randf() * TAU).scaled(Vector3(0.08, c._rng.randf_range(0.8, 1.6), 0.08)),
				c._em(p, 0.5)))
	c._lote(c._caixa(Vector3.ONE), juncos, [], c._material(Color(0.42, 0.5, 0.28)))
	# Píer: tábuas da margem para dentro e o barco amarrado.
	var dir := (c._mn + Vector2.ONE * c._lado * 0.5 - centro).normalized()
	var ini := centro + dir * raio
	var no := _no(c, ini, -dir)
	c._peca(no, Vector3(2.0, 0.15, 9.0), Vector3(0, 0.35, -4.5), Color(0.45, 0.33, 0.22))
	for k in 4:
		for x in [-0.9, 0.9]:
			c._peca(no, Vector3(0.18, 1.2, 0.18), Vector3(x, 0.0, -1.0 - k * 2.5), Color(0.32, 0.24, 0.17))
	c._peca(no, Vector3(1.6, 0.6, 4.0), Vector3(2.2, 0.2, -7.0), Color(0.75, 0.75, 0.72))
	# Árvores secas: tronco cinza e dois galhos.
	for k in 8:
		var a := c._rng.randf() * TAU
		var p := centro + Vector2.from_angle(a) * (raio + c._rng.randf_range(2.0, 6.0))
		if not c._livre(p, 0.8):
			continue
		c._reservas.append([p, 1.0])
		var arv := _no(c, p)
		var h := c._rng.randf_range(4.0, 7.0)
		var cinza := Color(0.42, 0.4, 0.38)
		_cilindro(arv, 0.22, 0.12, h, Vector3(0, h * 0.5, 0), cinza, 5)
		c._peca(arv, Vector3(0.1, 2.0, 0.1), Vector3(0.5, h * 0.7, 0), cinza, Basis(Vector3.BACK, -0.7))
		c._peca(arv, Vector3(0.1, 1.6, 0.1), Vector3(-0.4, h * 0.55, 0.2), cinza, Basis(Vector3.BACK, 0.8))


# --- Claustro (Claustro Vazio) -----------------------------------------------------

## As ruínas do claustro: o pátio quadrado com colunas e arcos (alguns caídos),
## muros quebrados e ciprestes.
static func _claustro(c: CenarioArena) -> void:
	c.pinheiro_fator = 0.5
	var z: Dictionary = _cantos(c)[0]
	var lado := 30.0
	var centro := _ponto(z, 4.0 + lado * 0.5, 4.0 + lado * 0.5)
	while lado > 10.0 and not c._livre(centro, lado * 0.72):
		lado -= 2.0
		centro = _ponto(z, 4.0 + lado * 0.5, 4.0 + lado * 0.5)
	if lado <= 10.0:
		return
	c._reservas.append([centro, lado * 0.72])
	c.direcao_fundo = (centro - (c._mn + Vector2.ONE * c._lado * 0.5)).normalized()
	var no := _no(c, centro, z["e1"])
	var pedra := COR_PEDRA
	var n := int(lado / 3.0)
	for lado_i in 4:
		var giro := Basis(Vector3.UP, PI * 0.5 * lado_i)
		for k in n + 1:
			if c._rng.randf() < 0.18:
				continue  # coluna caída
			var x := -lado * 0.5 + k * lado / n
			var pos := giro * Vector3(x, 0, -lado * 0.5)
			_cilindro(no, 0.6, 0.5, 6.5, pos + Vector3(0, 3.25, 0), pedra, 8)
			if k < n and c._rng.randf() < 0.75:
				c._peca(no, Vector3(lado / n + 0.9, 0.9, 1.2), giro * Vector3(x + lado / n * 0.5, 6.9, -lado * 0.5), pedra, giro)
	for k in 6:
		var x := c._rng.randf_range(-lado * 0.5, lado * 0.5)
		c._peca(no, Vector3(0.8, 0.8, 3.0), Vector3(x, 0.4, c._rng.randf_range(-lado * 0.3, lado * 0.3)), pedra.darkened(0.1),
				Basis(Vector3.UP, c._rng.randf() * TAU))
	c._peca(no, Vector3(lado + 2.0, c._rng.randf_range(3.0, 4.5), 1.0), Vector3(0, 1.8, lado * 0.5 + 1.5), pedra.darkened(0.15))
	# A torre do sino, meio desabada, no canto do pátio.
	c._peca(no, Vector3(4.0, 13.0, 4.0), Vector3(lado * 0.5 + 2.5, 6.5, -lado * 0.5 - 2.5), pedra.darkened(0.05))
	c._peca(no, Vector3(4.6, 0.6, 4.6), Vector3(lado * 0.5 + 2.5, 13.2, -lado * 0.5 - 2.5), pedra.darkened(0.2))
	# Ciprestes: cones altos e finos, verde escuro, em volta.
	var ciprestes := []
	for k in 24:
		var p := c._mn + Vector2(c._rng.randf(), c._rng.randf()) * c._lado
		if not c._livre(p, 1.2):
			continue
		c._reservas.append([p, 1.2])
		ciprestes.append(Transform3D(Basis(Vector3.UP, c._rng.randf() * TAU).scaled(Vector3.ONE * c._rng.randf_range(0.8, 1.3)), c._em(p)))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.9
	cone.height = 8.0
	cone.radial_segments = 6
	var arr := cone.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for v in vs.size():
		vs[v].y += 4.4
	arr[Mesh.ARRAY_VERTEX] = vs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	c._lote(m, ciprestes, [], c._material(Color(0.16, 0.3, 0.2)))
