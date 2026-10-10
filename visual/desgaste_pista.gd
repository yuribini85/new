class_name DesgastePista
extends RefCounted
## Imperfeições e elementos de autódromo sobre a pista montada (MontadorPista),
## gerados por regra, sem arte: a mesma pista sai sempre igual (semente pelo
## id). Só apresentação: nada aqui muda a corrida.
##
## No asfalto: tom irregular em manchas, linha de borracha no traçado (mais
## escura onde se freia e contorna), remendos, juntas, trincas, marcas de
## freada antigas antes das curvas lentas, manchas de óleo e o desgaste das
## faixas brancas. Em volta: muro de pneus atrás das caixas de areia e
## guard-rail ao longo das retas (fora da área dos boxes).

## Regras de composição (apresentação, não balanceamento).
const PASSO_M := 2.0
const BORRACHA_LARGURA_M := 2.6
const REMENDO_A_CADA_M := Vector2(70.0, 160.0)
const JUNTA_A_CADA_M := Vector2(45.0, 90.0)
const TRINCA_A_CADA_M := Vector2(25.0, 60.0)
const OLEO_A_CADA_M := Vector2(120.0, 260.0)
const FREADA_RAIO_M := 160.0  # curvas até este raio têm marcas de freada antigas
const FREADA_ANTES_M := 55.0
const DESGASTE_FAIXA_A_CADA_M := Vector2(6.0, 18.0)
const PNEU_RAIO_M := 0.33
const GUARDRAIL_FOLGA_M := 1.6  # além da faixa de escape
const POSTE_GUARDRAIL_M := 4.0

var _m: MontadorPista
var _rng := RandomNumberGenerator.new()
var _tracado: Tracado
var _mascara_suave: Texture2D


func montar(m: MontadorPista) -> void:
	_m = m
	_rng.seed = hash(m._pista.id + "desgaste")
	_tracado = Tracado.de(m._pista)
	_mascara_suave = _textura_suave()
	_asfalto()
	_protecoes()


# --- Asfalto -------------------------------------------------------------------

func _asfalto() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var comp := _m._pista.comprimento
	var meia := _m._largura * 0.5
	# Manchas grandes de tom (asfalto de idades diferentes).
	var s := _rng.randf_range(0.0, 40.0)
	while s < comp:
		var claro := _rng.randf() < 0.4
		var cor := Color(1, 1, 1, _rng.randf_range(0.03, 0.06)) if claro else Color(0, 0, 0, _rng.randf_range(0.08, 0.15))
		var largura := _rng.randf_range(meia * 0.8, meia * 2.0)
		var lat := _rng.randf_range(-meia + largura * 0.5, meia - largura * 0.5)
		_retangulo(st, s, lat, _rng.randf_range(18.0, 45.0), largura, cor)
		s += _rng.randf_range(25.0, 60.0)
	# Linha de borracha: o traçado escurece, mais nas curvas e freadas.
	_fita(st, 0.0, comp, func(x): return _tracado.lateral(x), BORRACHA_LARGURA_M,
			func(x): return Color(0.02, 0.02, 0.025, 0.11 + clampf(absf(_tracado.curvatura(x + 10.0)) * 60.0, 0.0, 0.16)))
	# Remendos: retângulos alinhados à pista, de outro tom, com borda viva.
	s = _rng.randf_range(20.0, REMENDO_A_CADA_M.x)
	while s < comp:
		var largura := _rng.randf_range(1.6, 4.0)
		var lat := _rng.randf_range(-meia + largura * 0.5 + 0.6, meia - largura * 0.5 - 0.6)
		var comp_r := _rng.randf_range(2.5, 8.0)
		var tom := Color(0, 0, 0, 0.16) if _rng.randf() < 0.6 else Color(1, 1, 1, 0.06)
		_retangulo(st, s, lat, comp_r, largura, tom, 0.1)
		# A emenda do remendo, mais escura, em volta.
		_retangulo(st, s, lat, comp_r + 0.16, largura + 0.16, Color(0, 0, 0, 0.12), 0.02)
		s += _rng.randf_range(REMENDO_A_CADA_M.x, REMENDO_A_CADA_M.y)
	# Juntas de asfalto: linhas finas atravessando a pista.
	s = _rng.randf_range(10.0, JUNTA_A_CADA_M.x)
	while s < comp:
		_retangulo(st, s, 0.0, 0.07, _m._largura - 0.4, Color(0, 0, 0, 0.22), 0.0)
		s += _rng.randf_range(JUNTA_A_CADA_M.x, JUNTA_A_CADA_M.y)
	# Trincas: linhas quebradas curtas, mais perto das bordas.
	s = _rng.randf_range(5.0, TRINCA_A_CADA_M.x)
	while s < comp:
		_trinca(st, s, _rng.randf_range(meia * 0.45, meia - 0.8) * (1.0 if _rng.randf() < 0.5 else -1.0))
		s += _rng.randf_range(TRINCA_A_CADA_M.x, TRINCA_A_CADA_M.y)
	# Marcas de freada antigas antes das curvas lentas, no traçado.
	for i in _m._pista.trechos.size():
		var t: Dictionary = _m._pista.trechos[i]
		var raio := float(t.get("raio_m", 0.0))
		if raio <= 0.0 or raio > FREADA_RAIO_M:
			continue
		var fim: float = _m._pista.inicios[i] + 6.0
		for k in _rng.randi_range(2, 4):
			var ini := fim - _rng.randf_range(FREADA_ANTES_M * 0.5, FREADA_ANTES_M)
			var desvio := _rng.randf_range(-0.6, 0.6)
			var forca := _rng.randf_range(0.1, 0.2)
			for lado in [-0.75, 0.75]:
				_fita(st, ini, fim - _rng.randf_range(0.0, 8.0),
						func(x): return clampf(_tracado.lateral(x) + desvio + lado, -meia + 0.3, meia - 0.3), 0.22,
						func(x): return Color(0.01, 0.01, 0.01, forca * _ponta(x, ini, fim)))
	# Manchas de óleo (o grid e a reta dos boxes ganham mais).
	s = _rng.randf_range(0.0, OLEO_A_CADA_M.x)
	while s < comp:
		_mancha(st, s, _rng.randf_range(-meia + 1.0, meia - 1.0), _rng.randf_range(0.8, 2.2))
		s += _rng.randf_range(OLEO_A_CADA_M.x, OLEO_A_CADA_M.y)
	for k in 6:
		_mancha(st, -_rng.randf_range(4.0, 60.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(0.6, 1.4))
	# Faixas brancas gastas: falhas de asfalto por cima delas.
	for lado in [-1.0, 1.0]:
		s = _rng.randf_range(0.0, DESGASTE_FAIXA_A_CADA_M.x)
		while s < comp:
			var lat: float = lado * (meia - 0.55 + 0.15 * lado)
			_retangulo(st, s, lat, _rng.randf_range(0.3, 1.8), 0.34, Color(0.12, 0.12, 0.13, _rng.randf_range(0.25, 0.55)), 0.15)
			s += _rng.randf_range(DESGASTE_FAIXA_A_CADA_M.x, DESGASTE_FAIXA_A_CADA_M.y)
	_por_na_cena(st, -0.012)


## Retângulo alinhado à pista: centro em (s, lat), `comp` ao longo, `larg` de
## lado. `borda`: fração macia nas bordas (0 = viva).
func _retangulo(st: SurfaceTool, s: float, lat: float, comp: float, larg: float, cor: Color, borda := 0.35) -> void:
	var rumo := _m._pista.rumo_em(s)
	var f := Vector2.from_angle(rumo)
	var l := Vector2.from_angle(rumo + PI / 2.0)
	var c := _m._ponto(s, lat)
	# Borda macia: a máscara inteira (UV 0..1); viva: só o miolo opaco dela.
	var u0 := 0.0 if borda >= 0.3 else 0.45
	var u1 := 1.0 - u0
	var cantos := [c - f * comp * 0.5 - l * larg * 0.5, c + f * comp * 0.5 - l * larg * 0.5,
			c + f * comp * 0.5 + l * larg * 0.5, c - f * comp * 0.5 + l * larg * 0.5]
	var uvs := [Vector2(u0, u0), Vector2(u1, u0), Vector2(u1, u1), Vector2(u0, u1)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(cor)
		st.set_uv(uvs[idx])
		st.add_vertex(MontadorPista._v3(cantos[idx], 0.0))


## Fita ao longo da pista de s0 a s1, centrada em lat(s), com cor(s).
func _fita(st: SurfaceTool, s0: float, s1: float, lat: Callable, larg: float, cor: Callable) -> void:
	var antes := []
	var s := s0
	while true:
		var c := _m._ponto(s, float(lat.call(s)))
		var l := Vector2.from_angle(_m._pista.rumo_em(s) + PI / 2.0)
		var col: Color = cor.call(s)
		var atual := [[c - l * larg * 0.5, Vector2(0.0, 0.5), col], [c + l * larg * 0.5, Vector2(1.0, 0.5), col]]
		if not antes.is_empty():
			for p in [antes[0], antes[1], atual[0], antes[1], atual[1], atual[0]]:
				st.set_color(p[2])
				st.set_uv(p[1])
				st.add_vertex(MontadorPista._v3(p[0], 0.0))
		antes = atual
		if s >= s1:
			break
		s = minf(s + PASSO_M, s1)


## Alfa que entra e sai nas pontas de [a, b].
static func _ponta(x: float, a: float, b: float) -> float:
	return smoothstep(a, a + 6.0, x) * (1.0 - smoothstep(b - 3.0, b, x))


func _trinca(st: SurfaceTool, s: float, lat: float) -> void:
	var p := _m._ponto(s, lat)
	var ang := _m._pista.rumo_em(s) + _rng.randf_range(-1.2, 1.2)
	for k in _rng.randi_range(3, 6):
		ang += _rng.randf_range(-0.7, 0.7)
		var q := p + Vector2.from_angle(ang) * _rng.randf_range(0.4, 1.1)
		var l := Vector2.from_angle(ang + PI / 2.0) * 0.03
		var cor := Color(0, 0, 0, 0.35)
		for idx in [[p - l, 0.0], [q - l, 0.0], [q + l, 1.0], [p - l, 0.0], [q + l, 1.0], [p + l, 1.0]]:
			st.set_color(cor)
			st.set_uv(Vector2(idx[1], 0.5))
			st.add_vertex(MontadorPista._v3(idx[0], 0.0))
		p = q


func _mancha(st: SurfaceTool, s: float, lat: float, raio: float) -> void:
	s = fposmod(s, _m._pista.comprimento)
	_retangulo(st, s, lat, raio * 2.0 * _rng.randf_range(0.8, 1.3), raio * 2.0, Color(0.02, 0.02, 0.03, _rng.randf_range(0.18, 0.3)), 0.5)


## Uma malha só para todas as marcas do asfalto (uma chamada de desenho).
func _por_na_cena(st: SurfaceTool, y: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _mascara_suave
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = -2
	mi.material_override = mat
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_m._cena.add_child(mi)


## Branca, opaca no miolo, sumindo nas bordas (u e v): a mesma serve de borda
## macia (UV 0..1) e de borda viva (só o miolo).
static func _textura_suave() -> Texture2D:
	var lado := 64
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	for y in lado:
		for x in lado:
			var u := (x + 0.5) / lado
			var v := (y + 0.5) / lado
			var k := smoothstep(0.0, 0.35, minf(u, 1.0 - u)) * smoothstep(0.0, 0.35, minf(v, 1.0 - v))
			img.set_pixel(x, y, Color(1, 1, 1, k))
	return ImageTexture.create_from_image(img)


# --- Em volta da pista -------------------------------------------------------

func _protecoes() -> void:
	var pneus := []  # Transform3D
	var cores_pneu := []
	var meia := _m._largura * 0.5
	# Muro de pneus atrás das caixas de areia e brita (por fora das curvas).
	for i in _m._pista.trechos.size():
		var t: Dictionary = _m._pista.trechos[i]
		var raio := float(t.get("raio_m", 0.0))
		if raio <= 0.0 or raio > MontadorPista.RAIO_BRITA_M:
			continue
		var fora := -1.0 if t.get("sentido", "esquerda") == "esquerda" else 1.0
		var largo := MontadorPista.AREIA_M if raio <= MontadorPista.RAIO_AREIA_M else MontadorPista.BRITA_M
		var lat := (meia + MontadorPista.ESCAPE_M + largo + 0.6) * fora
		var s0: float = _m._pista.inicios[i] - 5.0
		var s1: float = _m._pista.inicios[i] + float(t["comprimento_m"]) + 25.0
		var s := s0
		var n := 0
		while s < s1:
			for fila in 2:
				var p := _m._ponto(s + (PNEU_RAIO_M if fila == 1 else 0.0), lat + fora * fila * PNEU_RAIO_M * 1.7)
				if _m._reservado(p):
					continue
				pneus.append(Transform3D(Basis.IDENTITY, MontadorPista._v3(p, 0.15)))
				# Faixa pintada a cada tantos pneus (branco/vermelho), como nos muros de verdade.
				var pintado := (n / 6) % 2 == 1
				cores_pneu.append(Color(0.85, 0.85, 0.82) if pintado and fila == 0 else Color(0.08, 0.08, 0.09))
			s += PNEU_RAIO_M * 2.0
			n += 1
	if not pneus.is_empty():
		var cil := CylinderMesh.new()
		cil.top_radius = PNEU_RAIO_M
		cil.bottom_radius = PNEU_RAIO_M
		cil.height = 0.3
		cil.radial_segments = 10
		cil.rings = 1
		_multi(cil, pneus, cores_pneu)
	# Guard-rail nas retas, dos dois lados, fora da área dos boxes e das caixas.
	var trilhos := SurfaceTool.new()
	trilhos.begin(Mesh.PRIMITIVE_TRIANGLES)
	var postes := []
	var cores_poste := []
	for i in _m._pista.trechos.size():
		var t: Dictionary = _m._pista.trechos[i]
		if float(t.get("raio_m", 0.0)) > 0.0:
			continue
		var s0: float = _m._pista.inicios[i] + 8.0
		var s1: float = _m._pista.inicios[i] + float(t["comprimento_m"]) - 8.0
		for lado in [-1.0, 1.0]:
			var lat: float = lado * (meia + MontadorPista.ESCAPE_M + GUARDRAIL_FOLGA_M)
			var s := s0
			var antes := Vector2.INF
			while s <= s1:
				var p := _m._ponto(s, lat)
				var livre := not _m._reservado(p) and not _m._reservado(_m._ponto(s, lat + lado * 2.0))
				if livre:
					postes.append(Transform3D(Basis.IDENTITY, MontadorPista._v3(p, 0.35)))
					cores_poste.append(Color(0.3, 0.31, 0.33))
					if antes != Vector2.INF:
						_trilho(trilhos, antes, p)
					antes = p
				else:
					antes = Vector2.INF
				s += POSTE_GUARDRAIL_M
	if not postes.is_empty():
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.14, 0.7, 0.14)
		_multi(caixa, postes, cores_poste)
		var mi := MeshInstance3D.new()
		mi.mesh = trilhos.commit()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		_m._cena.add_child(mi)


## Lâmina do guard-rail entre dois postes: uma faixa clara de pé (frente) e o
## topo, para ler tanto de cima quanto inclinado.
func _trilho(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var tinta: Color = _m._tema.get("tinta", Color.WHITE)
	var claro := Color(0.78, 0.8, 0.82) * tinta
	var sombra := Color(0.45, 0.47, 0.5) * tinta
	var l := (b - a).orthogonal().normalized() * 0.08
	var va := [MontadorPista._v3(a - l, 0.55), MontadorPista._v3(b - l, 0.55), MontadorPista._v3(b + l, 0.55), MontadorPista._v3(a + l, 0.55)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(claro)
		st.add_vertex(va[idx])
	var vb := [MontadorPista._v3(a, 0.25), MontadorPista._v3(b, 0.25), MontadorPista._v3(b, 0.55), MontadorPista._v3(a, 0.55)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(sombra)
		st.add_vertex(vb[idx])


func _multi(malha: Mesh, transformacoes: Array, cores: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malha
	mm.instance_count = transformacoes.size()
	var tinta: Color = _m._tema.get("tinta", Color.WHITE)
	for k in transformacoes.size():
		mm.set_instance_transform(k, transformacoes[k])
		mm.set_instance_color(k, cores[k] * tinta)
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	_m._cena.add_child(mi)
