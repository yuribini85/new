class_name CenarioArena
extends Node3D
## Acabamento da arena vista de longe (pedido do usuário, referência de maquete):
## laterais do bloco de terreno em camadas de terra, barreira de concreto
## contínua no muro, alambrado com placas de patrocínio, torres de luz com
## bandeirinhas, estrada de terra com portão, cercas e o paddock (tendas das
## equipes, caminhões, guincho e barraca de comida), pinheiros e pedras na grama;
## copas e bandeirinhas balançam com o vento. Só tela: a simulação não vê
## nada disto (o muro dela continua na mesma linha). Malhas simples, sem textura;
## o que se repete vai em MultiMesh (celular).

## Profundidade do bloco abaixo do chão de fora e as camadas da lateral (de cima
## para baixo: fração da profundidade e cor).
const BASE_FUNDO_M := 16.0
const CAMADAS := [[0.06, Color(0.36, 0.52, 0.27)], [0.3, Color(0.79, 0.62, 0.45)], [0.55, Color(0.72, 0.45, 0.36)],
		[0.78, Color(0.6, 0.37, 0.33)], [1.0, Color(0.45, 0.3, 0.3)]]
const BARREIRA_ALTURA_M := 0.95
const BARREIRA_BASE_M := 0.7
const BARREIRA_TOPO_M := 0.24
const ALAMBRADO_RECUO_M := 1.5
const ALAMBRADO_ALTURA_M := 2.6
const ALAMBRADO_POSTE_M := 3.0
const TORRES := 6
const TORRE_ALTURA_M := 13.0
const TORRE_RECUO_M := 2.6
const BANDEIRA_PASSO_M := 1.3
const BANDEIRA_FLECHA_M := 0.9  # quanto o cordão cai no meio
const BANDEIRA_ALTURA_M := 4.2
const CORES_BANDEIRA := [Color(0.85, 0.2, 0.15), Color(0.95, 0.75, 0.15), Color(0.2, 0.45, 0.8), Color(0.95, 0.95, 0.92)]
const ESTRADA_LARGURA_M := 6.0
const PINHEIRO_POR_M2 := 1.0 / 90.0  # densidade média na grama do bloco
const PEDRAS := 45
const PEDRAS_CORTE_POR_LADO := 7
const LIVRE_DO_MURO_M := 4.0  # árvore e pedra começam depois do alambrado
const LIVRE_DA_ARQUIBANCADA_M := 11.0
const COR_MADEIRA := Color(0.42, 0.29, 0.19)
const COR_ACO := Color(0.25, 0.27, 0.27)

var _forma: ArenaForma
var _rng := RandomNumberGenerator.new()
var _mn := Vector2.ZERO
var _lado := 0.0
## Lado do muro de onde sai a estrada (−1 sem estrada) e a linha dela (2D).
var lado_estrada := -1
var _estrada: Array = []  # [início no muro, fim na borda do bloco]
var _ocupados: Array = []
var _concreto: Array = []
var _cores: Array = []  # das equipes da luta (tendas, caminhões, placas)
var _reservas: Array = []  # [centro (2D), raio]: o paddock; árvores e pedras desviam
## Vento: copas e bandeirinhas (desligado com Reduzir animações).
const VENTO_COPA := 1.0
const VENTO_BANDEIRA := 1.0
const PLACAS_MAX := 16
const PLACA_LARGURA_M := 3.6
const PLACA_ALTURA_M := 0.9
const MARCAS_RESERVA := ["Hayase", "Bancroft", "Kanaya", "Feldhaus", "Ridgeway", "Hozuki", "Mizuchi", "Keldorf"]
const COR_LONA := Color(0.92, 0.9, 0.85)


## forma: a da simulação; mn e lado: o quadrado do bloco (2D); ocupados: lados
## do muro com arquibancada; concreto: trechos com a barreira quebrável do
## pacote de dano (a contínua pula); semente: o mesmo cenário para a mesma arena.
## cores: das equipes da luta (o paddock e as placas usam).
func montar(forma: ArenaForma, mn: Vector2, lado: float, ocupados: Array, concreto: Array, semente: int,
		cores: Array = []) -> void:
	_forma = forma
	_mn = mn
	_lado = lado
	_ocupados = ocupados
	_concreto = concreto
	_cores = cores if not cores.is_empty() else [Color(0.8, 0.2, 0.15), Color(0.15, 0.4, 0.75), Color(0.95, 0.7, 0.1)]
	_rng.seed = semente
	_escolher_estrada()
	_laterais()
	_barreira()
	_alambrado()
	_placas()
	_torres()
	_estrada_e_portao()
	_paddock()
	_pinheiros()
	_pedras()


func _em(q: Vector2, dy := 0.0) -> Vector3:
	return Vector3(q.x, _forma.altura(q) + dy, -q.y)


func _material(cor := Color.WHITE, cores_vertice := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.vertex_color_use_as_albedo = cores_vertice
	m.roughness = 0.95
	return m


## Material que balança com o vento: o deslocamento cresce com a altura do
## vértice (copa) ou com a distância do cordão (bandeirinha, que tremula).
func _material_vento(bandeira: bool) -> Material:
	var forca := 0.0 if Preferencias.reduzir_animacoes else (VENTO_BANDEIRA if bandeira else VENTO_COPA)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode %s;
uniform float forca = 1.0;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	%s
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.95;
}
""" % ["cull_disabled" if bandeira else "cull_back",
			"VERTEX.z += sin(TIME * 7.0 + w.x * 0.9 + w.z * 0.7) * 0.18 * forca * -VERTEX.y;" if bandeira
			else "float f = sin(TIME * 1.6 + w.x * 0.21 + w.z * 0.17) + 0.4 * sin(TIME * 3.1 + w.z * 0.5); VERTEX.x += f * forca * 0.035 * max(VERTEX.y - 1.0, 0.0);"]
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("forca", forca)
	return m


func _malha(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


## MultiMesh com uma transformação (e cor, se houver) por instância.
func _lote(mesh: Mesh, xs: Array, cores: Array = [], mat: Material = null) -> void:
	if xs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cores.is_empty()
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat if mat != null else _material(Color.WHITE, mm.use_colors)
	add_child(mmi)


func _caixa(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b


## Transformação de uma peça de `a` a `b` (3D), com a caixa unitária esticada no Z.
func _ligando(a: Vector3, b: Vector3, grossura: float) -> Transform3D:
	var meio := (a + b) * 0.5
	var d := b - a
	var base := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	return Transform3D(Basis(base.x * grossura, base.y * grossura, base.z * d.length()), meio)


# --- Bloco --------------------------------------------------------------------------

## As quatro laterais do quadrado, do chão até o fundo, em faixas de cor com a
## divisa ondulada (camadas de terra, como num corte de maquete).
func _laterais() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fundo := _forma.altura(_mn) - BASE_FUNDO_M
	var cantos := [_mn, _mn + Vector2(_lado, 0), _mn + Vector2(_lado, _lado), _mn + Vector2(0, _lado)]
	for k in 4:
		var a: Vector2 = cantos[k]
		var b: Vector2 = cantos[(k + 1) % 4]
		var passos := int(_lado / 2.0)
		for s in passos:
			var p0 := a.lerp(b, float(s) / passos)
			var p1 := a.lerp(b, float(s + 1) / passos)
			var topo0 := _forma.altura(p0)
			var topo1 := _forma.altura(p1)
			var cima0 := topo0
			var cima1 := topo1
			for c in CAMADAS.size():
				var f: float = CAMADAS[c][0]
				var onda0 := 0.0 if c == CAMADAS.size() - 1 else sin(p0.length() * 0.21 + c * 1.7) * 0.35
				var onda1 := 0.0 if c == CAMADAS.size() - 1 else sin(p1.length() * 0.21 + c * 1.7) * 0.35
				var baixo0 := lerpf(topo0, fundo, f) + onda0
				var baixo1 := lerpf(topo1, fundo, f) + onda1
				if c == 0:
					baixo0 = topo0 - 0.45
					baixo1 = topo1 - 0.45
				var cor: Color = CAMADAS[c][1]
				var v := [Vector3(p0.x, cima0, -p0.y), Vector3(p1.x, cima1, -p1.y),
						Vector3(p1.x, baixo1, -p1.y), Vector3(p0.x, baixo0, -p0.y)]
				for i in [0, 1, 2, 0, 2, 3]:
					st.set_color(cor)
					st.add_vertex(v[i])
				cima0 = baixo0
				cima1 = baixo1
	st.generate_normals()
	var mi := _malha(st.commit(), _material(Color.WHITE, true))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pedras_no_corte(cantos, fundo)
	_sombra_do_bloco(fundo)


## Pedras saindo das camadas de terra, meio enterradas na lateral.
func _pedras_no_corte(cantos: Array, fundo: float) -> void:
	var xs := []
	var cores := []
	for k in 4:
		var a: Vector2 = cantos[k]
		var b: Vector2 = cantos[(k + 1) % 4]
		# O quadrado é anti-horário no plano 2D: para fora é a direita da aresta.
		var fora := (b - a).normalized().orthogonal()
		for j in PEDRAS_CORTE_POR_LADO:
			var q := a.lerp(b, _rng.randf_range(0.05, 0.95))
			var y := lerpf(_forma.altura(q) - 1.0, fundo + 1.0, _rng.randf_range(0.15, 0.9))
			var esc := Vector3(_rng.randf_range(0.8, 1.8), _rng.randf_range(0.5, 1.1), _rng.randf_range(0.8, 1.8))
			var giro := Basis(Vector3.UP, _rng.randf() * TAU)
			xs.append(Transform3D(giro.scaled(esc), Vector3(q.x + fora.x * 0.2, y, -(q.y + fora.y * 0.2))))
			var g := _rng.randf_range(0.48, 0.6)
			cores.append(Color(g, g * 0.96, g * 0.92))
	var esfera := SphereMesh.new()
	esfera.radius = 0.9
	esfera.height = 1.8
	esfera.radial_segments = 6
	esfera.rings = 3
	_lote(esfera, xs, cores)


## Sombra suave embaixo do bloco, no fundo claro: ele assenta em vez de flutuar.
func _sombra_do_bloco(fundo: float) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.45))
	grad.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * _lado * 1.5
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := _malha(plano, m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var centro := _mn + Vector2.ONE * _lado * 0.5
	mi.position = Vector3(centro.x, fundo - 2.0, -centro.y)


# --- Muro ---------------------------------------------------------------------------

func _no_concreto(q: Vector2) -> bool:
	for tr in _concreto:
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, tr[0], tr[1])) < 1.4:
			return true
	return false


## Barreira tipo New Jersey contínua, a face de dentro na linha do muro; onde já
## há a barreira quebrável do pacote de dano, ela pula.
func _barreira() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var perfil := [Vector2(0.0, 0.0), Vector2(0.0, 0.25), Vector2((BARREIRA_BASE_M - BARREIRA_TOPO_M) * 0.5, BARREIRA_ALTURA_M),
			Vector2((BARREIRA_BASE_M + BARREIRA_TOPO_M) * 0.5, BARREIRA_ALTURA_M), Vector2(BARREIRA_BASE_M, 0.25), Vector2(BARREIRA_BASE_M, 0.0)]
	var n := _forma.muro.size()
	for i in n:
		var a := _forma.muro[i]
		var b := _forma.muro[(i + 1) % n]
		var fora := (b - a).normalized().orthogonal()
		var passos := maxi(int((b - a).length() / 1.0), 1)
		for s in passos:
			# Um pouco além das pontas: fecha a quina com o lado vizinho.
			var p0 := a.lerp(b, float(s) / passos) - (b - a).normalized() * (0.3 if s == 0 else 0.0)
			var p1 := a.lerp(b, float(s + 1) / passos) + (b - a).normalized() * (0.3 if s == passos - 1 else 0.0)
			if _no_concreto((p0 + p1) * 0.5):
				continue
			var h0 := _forma.altura(p0 + fora * 0.35) - 0.1
			var h1 := _forma.altura(p1 + fora * 0.35) - 0.1
			for k in perfil.size() - 1:
				var u: Vector2 = perfil[k]
				var w: Vector2 = perfil[k + 1]
				var v := [Vector3(p0.x + fora.x * u.x, h0 + u.y, -(p0.y + fora.y * u.x)),
						Vector3(p1.x + fora.x * u.x, h1 + u.y, -(p1.y + fora.y * u.x)),
						Vector3(p1.x + fora.x * w.x, h1 + w.y, -(p1.y + fora.y * w.x)),
						Vector3(p0.x + fora.x * w.x, h0 + w.y, -(p0.y + fora.y * w.x))]
				# Faixa de tinta no pé (amarela e preta, como em pista): a cada 2 m.
				var cor := Color(0.72, 0.71, 0.66)
				if k == 0 and int(float(s) / 2.0) % 2 == 0:
					cor = Color(0.85, 0.68, 0.15)
				for j in [0, 2, 1, 0, 3, 2]:
					st.set_color(cor)
					st.add_vertex(v[j])
	st.generate_normals()
	_malha(st.commit(), _material(Color.WHITE, true))


## Alambrado atrás da barreira: postes de aço e a tela (translúcida); abre na
## estrada.
func _alambrado() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var postes := []
	var n := _forma.muro.size()
	for i in n:
		var a := _forma.muro[i]
		var b := _forma.muro[(i + 1) % n]
		var fora := (b - a).normalized().orthogonal()
		var comp := (b - a).length()
		var passos := maxi(int(comp / ALAMBRADO_POSTE_M), 1)
		for s in passos:
			var p0 := a.lerp(b, float(s) / passos) + fora * ALAMBRADO_RECUO_M
			var p1 := a.lerp(b, float(s + 1) / passos) + fora * ALAMBRADO_RECUO_M
			if i == lado_estrada and absf(float(s) + 0.5 - passos * 0.5) * comp / passos < ESTRADA_LARGURA_M * 0.5 + 1.0:
				continue
			var b0 := _em(p0)
			var b1 := _em(p1)
			var v := [b0, b1, b1 + Vector3.UP * ALAMBRADO_ALTURA_M, b0 + Vector3.UP * ALAMBRADO_ALTURA_M]
			for j in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(v[j])
			postes.append(Transform3D(Basis.IDENTITY, b0 + Vector3.UP * ALAMBRADO_ALTURA_M * 0.5))
	var tela := StandardMaterial3D.new()
	tela.albedo_color = Color(0.3, 0.32, 0.33, 0.38)
	tela.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tela.cull_mode = BaseMaterial3D.CULL_DISABLED
	tela.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := _malha(st.commit(), tela)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var poste := CylinderMesh.new()
	poste.top_radius = 0.05
	poste.bottom_radius = 0.05
	poste.height = ALAMBRADO_ALTURA_M + 0.1
	poste.radial_segments = 5
	_lote(poste, postes, [], _material(COR_ACO))


# --- Torres de luz e bandeirinhas ---------------------------------------------------------

## Torres nos cantos do muro (espalhadas), viradas para o centro; bandeirinhas
## por cima do alambrado, de canto a canto (num mastro onde não há torre).
func _torres() -> void:
	var n := _forma.muro.size()
	var quantas := mini(TORRES, n)
	var postes := []
	var cabecas := []
	var lampadas := []
	for k in quantas:
		var i := int(round(float(k) * n / quantas)) % n
		var prev := _forma.muro[(i - 1 + n) % n]
		var q := _forma.muro[i]
		var nxt := _forma.muro[(i + 1) % n]
		var fora := ((q - prev).normalized().orthogonal() + (nxt - q).normalized().orthogonal()).normalized()
		var p := q + fora * TORRE_RECUO_M
		var base := _em(p)
		postes.append(Transform3D(Basis.IDENTITY, base + Vector3.UP * TORRE_ALTURA_M * 0.5))
		var para := Vector3(-fora.x, 0.0, fora.y)
		var rumo := Basis.looking_at(para, Vector3.UP).rotated(Basis.looking_at(para, Vector3.UP).x, -0.35)
		var topo := base + Vector3.UP * TORRE_ALTURA_M
		cabecas.append(Transform3D(rumo, topo))
		for lx in [-0.75, -0.25, 0.25, 0.75]:
			for ly in [-0.22, 0.22]:
				lampadas.append(Transform3D(rumo, topo + rumo * Vector3(lx, ly, -0.17)))
	var poste := CylinderMesh.new()
	poste.top_radius = 0.14
	poste.bottom_radius = 0.22
	poste.height = TORRE_ALTURA_M
	poste.radial_segments = 6
	_lote(poste, postes, [], _material(COR_ACO))
	_lote(_caixa(Vector3(2.0, 0.8, 0.25)), cabecas, [], _material(Color(0.18, 0.19, 0.2)))
	var luz := StandardMaterial3D.new()
	luz.albedo_color = Color(1.0, 0.95, 0.75)
	luz.emission_enabled = true
	luz.emission = Color(1.0, 0.92, 0.6)
	luz.emission_energy_multiplier = 1.6
	_lote(_caixa(Vector3(0.4, 0.3, 0.08)), lampadas, [], luz)
	_bandeirinhas()


func _bandeirinhas() -> void:
	var n := _forma.muro.size()
	var topos := []
	var mastros := []
	for i in n:
		var q := _forma.muro[i]
		var fora := ((q - _forma.muro[(i - 1 + n) % n]).normalized().orthogonal()
				+ (_forma.muro[(i + 1) % n] - q).normalized().orthogonal()).normalized()
		var base := _em(q + fora * ALAMBRADO_RECUO_M)
		topos.append(base + Vector3.UP * BANDEIRA_ALTURA_M)
		mastros.append(Transform3D(Basis.IDENTITY, base + Vector3.UP * BANDEIRA_ALTURA_M * 0.5))
	var mastro := CylinderMesh.new()
	mastro.top_radius = 0.06
	mastro.bottom_radius = 0.08
	mastro.height = BANDEIRA_ALTURA_M
	mastro.radial_segments = 5
	_lote(mastro, mastros, [], _material(COR_MADEIRA))
	var cordas := []
	var bandeiras := []
	var cores := []
	var tri := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.32, 0, 0), Vector3(0.32, 0, 0), Vector3(0, -0.6, 0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var c := 0
	for k in topos.size():
		var a: Vector3 = topos[k]
		var b: Vector3 = topos[(k + 1) % topos.size()]
		var passos := maxi(int(a.distance_to(b) / BANDEIRA_PASSO_M), 2)
		var anterior := a
		for s in range(1, passos + 1):
			var t := float(s) / passos
			var p := a.lerp(b, t) - Vector3.UP * BANDEIRA_FLECHA_M * 4.0 * t * (1.0 - t)
			cordas.append(_ligando(anterior, p, 0.03))
			if s < passos:
				var dir := (b - a)
				dir.y = 0.0
				bandeiras.append(Transform3D(Basis.looking_at(dir.normalized().cross(Vector3.UP), Vector3.UP), p))
				cores.append(CORES_BANDEIRA[c % CORES_BANDEIRA.size()])
				c += 1
			anterior = p
	_lote(_caixa(Vector3.ONE), cordas, [], _material(Color(0.15, 0.15, 0.15)))
	_lote(tri, bandeiras, cores, _material_vento(true))


# --- Estrada, portão e cercas -----------------------------------------------------

## A estrada sai do lado mais comprido sem arquibancada, do meio dele até a borda
## do bloco, na direção de fora.
func _escolher_estrada() -> void:
	var n := _forma.muro.size()
	var melhor := 0.0
	for i in n:
		if i in _ocupados:
			continue
		var comp := (_forma.muro[(i + 1) % n] - _forma.muro[i]).length()
		if comp > melhor and comp > ESTRADA_LARGURA_M + 4.0:
			melhor = comp
			lado_estrada = i
	if lado_estrada < 0:
		return
	var a := _forma.muro[lado_estrada]
	var b := _forma.muro[(lado_estrada + 1) % n]
	var fora := (b - a).normalized().orthogonal()
	var ini := a.lerp(b, 0.5) + fora * 0.8
	# Até a borda do quadrado.
	var t := INF
	for eixo in 2:
		if absf(fora[eixo]) > 1e-4:
			var limite := _mn[eixo] + (_lado if fora[eixo] > 0.0 else 0.0)
			t = minf(t, (limite - ini[eixo]) / fora[eixo])
	_estrada = [ini, ini + fora * t]


func _perto_da_estrada(q: Vector2, folga: float) -> bool:
	if _estrada.is_empty():
		return false
	return q.distance_to(Geometry2D.get_closest_point_to_segment(q, _estrada[0], _estrada[1])) < ESTRADA_LARGURA_M * 0.5 + folga


func _estrada_e_portao() -> void:
	if _estrada.is_empty():
		return
	var a: Vector2 = _estrada[0]
	var b: Vector2 = _estrada[1]
	var dir := (b - a).normalized()
	var lado := dir.orthogonal()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passos := maxi(int(a.distance_to(b) / 1.5), 1)
	for s in passos:
		var p0 := a.lerp(b, float(s) / passos)
		var p1 := a.lerp(b, float(s + 1) / passos)
		var v := [_em(p0 - lado * ESTRADA_LARGURA_M * 0.5, 0.06), _em(p1 - lado * ESTRADA_LARGURA_M * 0.5, 0.06),
				_em(p1 + lado * ESTRADA_LARGURA_M * 0.5, 0.06), _em(p0 + lado * ESTRADA_LARGURA_M * 0.5, 0.06)]
		for j in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(v[j])
	st.generate_normals()
	var mi := _malha(st.commit(), _material(Color(0.55, 0.42, 0.3)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Portão de madeira na linha do alambrado: dois postes e a trave com placa.
	var pecas := []
	var meio := a + dir * (ALAMBRADO_RECUO_M - 0.8)
	var esq := _em(meio - lado * (ESTRADA_LARGURA_M * 0.5 + 0.3))
	var dir3 := _em(meio + lado * (ESTRADA_LARGURA_M * 0.5 + 0.3))
	for p in [esq, dir3]:
		pecas.append(_ligando(p, p + Vector3.UP * 5.0, 0.4))
	pecas.append(_ligando(esq + Vector3.UP * 4.6, dir3 + Vector3.UP * 4.6, 0.35))
	pecas.append(_ligando(esq + Vector3.UP * 3.9 + (dir3 - esq) * 0.25, dir3 + Vector3.UP * 3.9 - (dir3 - esq) * 0.25, 0.7))
	# Cercas de madeira dos dois lados da estrada: mourões e duas tábuas.
	var cerca_passos := int(a.distance_to(b) / 3.0)
	for k in [-1.0, 1.0]:
		for s in range(1, cerca_passos):
			var p0 := _em(a + dir * (s * 3.0) + lado * k * (ESTRADA_LARGURA_M * 0.5 + 0.8))
			var p1 := _em(a + dir * ((s + 1) * 3.0) + lado * k * (ESTRADA_LARGURA_M * 0.5 + 0.8))
			pecas.append(_ligando(p0, p0 + Vector3.UP * 1.2, 0.14))
			if s < cerca_passos - 1:
				for altura in [0.5, 0.95]:
					pecas.append(_ligando(p0 + Vector3.UP * altura, p1 + Vector3.UP * altura, 0.08))
	_lote(_caixa(Vector3.ONE), pecas, [], _material(COR_MADEIRA))


# --- Vegetação ---------------------------------------------------------------------

## Ponto livre na grama: fora do alambrado, longe das arquibancadas, da
## estrada e das torres, dentro do bloco.
func _livre(q: Vector2, raio: float) -> bool:
	if q.x < _mn.x + raio + 0.5 or q.y < _mn.y + raio + 0.5 or q.x > _mn.x + _lado - raio - 0.5 or q.y > _mn.y + _lado - raio - 0.5:
		return false
	if _forma.dentro(q) or -float(_forma.muro_perto(q)[0]) < LIVRE_DO_MURO_M + raio:
		return false
	if _perto_da_estrada(q, 1.5 + raio):
		return false
	for r in _reservas:
		if q.distance_to(r[0]) < float(r[1]) + raio:
			return false
	var n := _forma.muro.size()
	for i in _ocupados:
		var a := _forma.muro[i]
		var b := _forma.muro[(i + 1) % n]
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)) < LIVRE_DA_ARQUIBANCADA_M + raio:
			return false
	return true


## Pinheiros em grupos (de 3 a 9, alturas diferentes), mais densos perto da
## borda do bloco; copa em três cones e tronco, cada um num lote.
func _pinheiros() -> void:
	var copas := []
	var cores := []
	var troncos := []
	var total := int(_lado * _lado * PINHEIRO_POR_M2)
	var tentativas := 0
	while copas.size() < total and tentativas < total * 30:
		tentativas += 1
		var centro := _mn + Vector2(_rng.randf(), _rng.randf()) * _lado
		if not _livre(centro, 1.5):
			continue
		for k in _rng.randi_range(3, 9):
			var q := centro + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1.5, 7.0)
			if not _livre(q, 1.2):
				continue
			var esc := _rng.randf_range(0.75, 1.6)
			var base := _em(q, -0.1)
			var giro := Basis(Vector3.UP, _rng.randf() * TAU)
			copas.append(Transform3D(giro.scaled(Vector3.ONE * esc), base))
			troncos.append(Transform3D(giro.scaled(Vector3.ONE * esc), base))
			cores.append(Color(0.2, 0.36, 0.22).lerp(Color(0.3, 0.45, 0.25), _rng.randf()))
			if copas.size() >= total:
				break
	_lote(_copa(), copas, cores, _material_vento(false))
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.16
	tronco.bottom_radius = 0.2
	tronco.height = 1.4
	tronco.radial_segments = 5
	var m := ArrayMesh.new()
	var arr := tronco.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for v in vs.size():
		vs[v].y += 0.7
	arr[Mesh.ARRAY_VERTEX] = vs
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_lote(m, troncos, [], _material(COR_MADEIRA))


## Copa do pinheiro: três cones de seis lados, empilhados, da base (1 m) até o
## topo (~6 m na escala 1).
func _copa() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.6 - k * 0.38
		cone.height = 2.4 - k * 0.3
		cone.radial_segments = 6
		cone.rings = 1
		var x := Transform3D(Basis.IDENTITY, Vector3(0, 1.0 + k * 1.35 + cone.height * 0.5, 0))
		st.append_from(cone, 0, x)
	st.generate_normals()
	return st.commit()


## Pedras facetadas (esfera de poucos lados, achatada) perto das árvores e da
## borda do bloco.
func _pedras() -> void:
	var xs := []
	var cores := []
	var tentativas := 0
	while xs.size() < PEDRAS and tentativas < PEDRAS * 30:
		tentativas += 1
		var q := _mn + Vector2(_rng.randf(), _rng.randf()) * _lado
		if not _livre(q, 0.8):
			continue
		var esc := Vector3(_rng.randf_range(0.6, 1.5), _rng.randf_range(0.4, 0.9), _rng.randf_range(0.6, 1.5))
		var giro := Basis(Vector3.UP, _rng.randf() * TAU).rotated(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
		xs.append(Transform3D(giro.scaled(esc), _em(q, 0.1)))
		var g := _rng.randf_range(0.5, 0.65)
		cores.append(Color(g, g * 0.98, g * 0.95))
	var esfera := SphereMesh.new()
	esfera.radius = 0.9
	esfera.height = 1.8
	esfera.radial_segments = 6
	esfera.rings = 3
	_lote(esfera, xs, cores)


# --- Placas de patrocínio --------------------------------------------------------

## Placas na face de dentro do alambrado, em lados alternados do muro, com as
## marcas (fictícias) dos fabricantes do jogo; cores das equipes da luta.
func _placas() -> void:
	var marcas := _marcas()
	var n := _forma.muro.size()
	var feitas := 0
	for i in n:
		if feitas >= PLACAS_MAX:
			break
		var a := _forma.muro[i]
		var b := _forma.muro[(i + 1) % n]
		var comp := (b - a).length()
		if comp < PLACA_LARGURA_M * 2.0:
			continue
		var dir := (b - a) / comp
		var fora := dir.orthogonal()
		var quantas := mini(int(comp / (PLACA_LARGURA_M * 2.5)), 3)
		for k in quantas:
			var t := (float(k) + 0.5) / quantas
			var q := a.lerp(b, t) + fora * (ALAMBRADO_RECUO_M - 0.06)
			if i == lado_estrada and absf(t - 0.5) * comp < ESTRADA_LARGURA_M:
				continue
			var cor: Color = _cores[(i + k) % _cores.size()]
			var base := _em(q, 0.25 + PLACA_ALTURA_M * 0.5)
			var para := Vector3(-fora.x, 0.0, fora.y)
			var giro := Basis.looking_at(-para, Vector3.UP)  # a frente (+Z) para a arena
			var placa := MeshInstance3D.new()
			placa.mesh = _caixa(Vector3(PLACA_LARGURA_M, PLACA_ALTURA_M, 0.05))
			placa.material_override = _material(cor)
			placa.transform = Transform3D(giro, base)
			add_child(placa)
			var texto := Label3D.new()
			texto.text = String(marcas[(i * 3 + k) % marcas.size()]).to_upper()
			texto.font_size = 64
			texto.outline_size = 0
			texto.pixel_size = 0.0075
			texto.modulate = Color.WHITE if cor.get_luminance() < 0.6 else Color(0.1, 0.1, 0.1)
			texto.position = Vector3(0, 0, 0.03)
			texto.shaded = true
			texto.double_sided = false
			placa.add_child(texto)
			feitas += 1


func _marcas() -> Array:
	var d := get_node_or_null("/root/Dados")
	if d == null:
		return MARCAS_RESERVA
	var vistas := {}
	for c in d.lista("carros"):
		var f := String(c.get("fabricante", ""))
		if f != "":
			vistas[f.capitalize()] = true
	var r := vistas.keys()
	r.sort()
	return r if not r.is_empty() else MARCAS_RESERVA


# --- Paddock ----------------------------------------------------------------------

## Ao longo da estrada, dos dois lados (depois das cercas): tendas nas cores das
## equipes, caminhão com carreta, guincho e barraca de comida, virados para ela.
func _paddock() -> void:
	if _estrada.is_empty():
		return
	var a: Vector2 = _estrada[0]
	var b: Vector2 = _estrada[1]
	var dir := (b - a).normalized()
	var lado := dir.orthogonal()
	var tipos := ["tenda", "caminhao", "tenda", "comida", "tenda", "guincho"]
	var k := 0
	var dist := 12.0
	while dist < a.distance_to(b) - 7.0 and k < 10:
		for sinal in [-1.0, 1.0]:
			var tipo: String = tipos[k % tipos.size()]
			var afasta := ESTRADA_LARGURA_M * 0.5 + 1.2 + (4.0 if tipo == "caminhao" else 3.0)
			var q: Vector2 = a + dir * dist + lado * float(sinal) * afasta
			var cor: Color = _cores[k % _cores.size()]
			# Virado para a estrada: a frente local (−Z) aponta para ela.
			var para := Vector3(-lado.x * float(sinal), 0.0, lado.y * float(sinal))
			var x := Transform3D(Basis.looking_at(para, Vector3.UP), _em(q))
			var no := Node3D.new()
			no.transform = x
			add_child(no)
			match tipo:
				"tenda":
					_tenda(no, cor)
				"caminhao":
					_caminhao(no, cor, false)
				"guincho":
					_caminhao(no, Color(0.95, 0.75, 0.1), true)
				"comida":
					_barraca(no)
			_reservas.append([q, 6.0 if tipo == "caminhao" else 4.0])
			k += 1
		dist += 10.0


func _peca(pai: Node3D, tam: Vector3, pos: Vector3, cor: Color, giro := Basis.IDENTITY) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _caixa(tam)
	m.material_override = _material(cor)
	m.transform = Transform3D(giro, pos)
	pai.add_child(m)
	return m


## Tenda 4 x 4 m: quatro pés, teto em pirâmide na cor da equipe e uma mesa.
func _tenda(no: Node3D, cor: Color) -> void:
	for px in [-1.9, 1.9]:
		for pz in [-1.9, 1.9]:
			_peca(no, Vector3(0.08, 2.3, 0.08), Vector3(px, 1.15, pz), COR_ACO)
	var teto := MeshInstance3D.new()
	var piramide := CylinderMesh.new()
	piramide.top_radius = 0.0
	piramide.bottom_radius = 2.85
	piramide.height = 1.0
	piramide.radial_segments = 4
	piramide.rings = 1
	teto.mesh = piramide
	teto.material_override = _material(cor)
	teto.position = Vector3(0, 2.8, 0)
	teto.rotation.y = PI * 0.25
	no.add_child(teto)
	# Saia da tenda (faixa branca) e a mesa com um pneu em cima.
	_peca(no, Vector3(4.0, 0.3, 0.04), Vector3(0, 2.15, -2.0), COR_LONA)
	_peca(no, Vector3(1.8, 0.08, 0.8), Vector3(0, 0.85, 0.6), Color(0.85, 0.85, 0.82))
	_peca(no, Vector3(0.6, 0.6, 0.25), Vector3(-0.4, 1.2, 0.6), Color(0.08, 0.08, 0.09))


## Caminhão com carreta (ou guincho: cabine e plataforma com o braço), cabine
## virada para a frente da estrada; faixa na cor da equipe.
func _caminhao(no: Node3D, cor: Color, guincho: bool) -> void:
	var lado := Basis(Vector3.UP, PI * 0.5)  # comprido ao longo da estrada
	var corpo := Node3D.new()
	corpo.transform = Transform3D(lado, Vector3.ZERO)
	no.add_child(corpo)
	_peca(corpo, Vector3(2.4, 2.4, 2.2), Vector3(0, 1.6, -4.2), cor)
	_peca(corpo, Vector3(2.3, 0.7, 0.05), Vector3(0, 2.1, -5.32), Color(0.25, 0.35, 0.42))  # para-brisa
	if guincho:
		_peca(corpo, Vector3(2.4, 0.3, 5.0), Vector3(0, 1.0, -0.6), Color(0.3, 0.3, 0.3))
		_peca(corpo, Vector3(0.3, 0.3, 3.0), Vector3(0, 2.2, 1.0), COR_ACO, Basis(Vector3.RIGHT, -0.5))
	else:
		_peca(corpo, Vector3(2.5, 3.0, 8.5), Vector3(0, 2.2, 1.6), Color(0.88, 0.88, 0.86))
		_peca(corpo, Vector3(2.52, 0.5, 8.0), Vector3(0, 2.4, 1.6), cor)  # faixa da equipe
	for z in ([-4.2, -0.8, 0.8] if guincho else [-4.2, 3.4, 4.8]):
		for x in [-1.15, 1.15]:
			var roda := MeshInstance3D.new()
			var cil := CylinderMesh.new()
			cil.top_radius = 0.5
			cil.bottom_radius = 0.5
			cil.height = 0.35
			cil.radial_segments = 8
			roda.mesh = cil
			roda.material_override = _material(Color(0.08, 0.08, 0.09))
			roda.transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 0.5, z))
			corpo.add_child(roda)


## Barraca de comida: balcão, toldo listrado inclinado e a placa.
func _barraca(no: Node3D) -> void:
	_peca(no, Vector3(3.0, 1.1, 1.4), Vector3(0, 0.55, 0), Color(0.75, 0.62, 0.45))
	_peca(no, Vector3(3.0, 1.4, 0.1), Vector3(0, 1.8, 0.65), Color(0.75, 0.62, 0.45))
	for k in 6:
		_peca(no, Vector3(0.5, 0.06, 1.8), Vector3(-1.25 + k * 0.5, 2.55, -0.25),
				Color(0.85, 0.15, 0.12) if k % 2 == 0 else COR_LONA, Basis(Vector3.RIGHT, 0.25))
