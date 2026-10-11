class_name Arena3D
extends SubViewportContainer
## Arena de destruição em 3D, de cima (decisão 50): só lê as amostras de
## Arena.correr (a simulação já resolveu tudo). Chão de terra batida num
## círculo, muro de pneus, carros com a mesma arte da corrida (sprite ou o
## carro em código). Dano por região: marcas escuras no ponto do carro, mais
## fortes a cada estágio (Arena.estagio); fumaça a partir do 4º estágio; o
## eliminado escurece e solta fumaça preta. Faíscas e um tranco de câmera nas
## batidas. A câmera enquadra os carros ainda vivos.

## Câmera em perspectiva, inclinada e girando devagar em volta da briga (a
## arena se lê como 3D: paredes, carros e destroços com volume e paralaxe).
const FOV_GRAUS := 45.0
const ELEVACAO_GRAUS := 34.0
const ORBITA_S := 48.0  # uma volta completa em volta do centro
const FOLGA_M := 9.0  # margem em volta dos carros no enquadramento
const DESTROCO_PERTO_M := 26.0  # destroço a essa distância da briga entra no quadro
const TAMANHO_MIN := 28.0
const TAMANHO_BRIGA_MAX := 72.0  # seguindo a sua briga, a câmera não abre além disso
const CAMERA_SUAVE := 2.5  # 1/s
const PNEUS_POR_M := 0.95
## Chão em malha: passo da grade e quanto passa do muro (m).
const CHAO_PASSO_M := 1.5
const CHAO_MARGEM_M := 10.0
## Direção da luz pré-calculada no chão (de onde vem a luz, normalizada).
const LUZ_CHAO := Vector3(0.55, 0.62, 0.56)
const FUMACA_ESTAGIO := 3  # estágio (0..4) a partir do qual sai fumaça

## Tempo atual da luta (s); quem mostra avança.
var tempo := 0.0

var _resultado: Dictionary = {}
var _amostras: Array = []
var _i := 0
var _mundo: Node3D
var _cena: Node3D
var _camera: Camera3D
## Faixas da pintura da Oficina por carro (id -> {padrao, faixa, filete}).
var faixas_pintura := {}
var _orbita := 0.0  # ângulo da câmera em volta do centro (rad)
var _carros := {}  # id -> Node3D
var _malhas := {}  # id -> [{mi, rel, surfs: [{arr, prim, mat}]}]: malhas originais da carroceria
var _estagio_visto := {}  # id -> estágio de dano por região já aplicado na malha
var _fumaca := {}  # id -> CPUParticles3D
var _eventos_vistos := 0
var _estagios := 5
var _raio := 45.0
var _forma: ArenaForma  # muro, obstáculos e relevo (a mesma forma da simulação)
var _centro := Vector3.ZERO
var _tamanho := 60.0
var _tremor := 0.0


func _init() -> void:
	stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_2X
	add_child(vp)
	_mundo = Node3D.new()
	vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.1, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.46)
	amb.environment = env
	_mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	# Luz baixa, de lado: as encostas do chão irregular ganham luz e sombra.
	luz.rotation = Vector3(-0.55, 0.75, 0)
	luz.shadow_enabled = not Preferencias.efeitos_leves
	luz.light_color = Color(1.0, 0.86, 0.7)
	_mundo.add_child(luz)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = FOV_GRAUS
	_camera.far = 2000.0
	_mundo.add_child(_camera)
	_cena = Node3D.new()
	_mundo.add_child(_cena)


## resultado: Arena.correr com amostras. modelos: id -> dados do carro;
## pinturas: id -> cor. params: data/arena.json.
func mostrar(resultado: Dictionary, params: Dictionary, modelos: Dictionary, pinturas: Dictionary = {}) -> void:
	for c in _cena.get_children():
		c.queue_free()
	_carros = {}
	_malhas = {}
	_estagio_visto = {}
	_fumaca = {}
	_resultado = resultado
	_amostras = resultado.get("amostras", [])
	_estagios = int(params.get("estagios", 5))
	_raio = float(params.get("raio_m", 45.0))
	_forma = ArenaForma.de(params)
	_i = 0
	_eventos_vistos = 0
	tempo = 0.0
	_construir_arena()
	for id in resultado["carros"]:
		var base: Dictionary = modelos.get(id, {"id": id, "categoria": "seda"})
		var cor: Color = pinturas.get(id, CarroBloco.cor_do_id(id))
		var c: Node3D = CarroDesenho.new()
		if CarroBloco.tem_glb(String(base.get("id", ""))) \
				or not c.configurar(String(base.get("id", "")), pinturas.get(id, Color(0, 0, 0, 0))):
			c.free()
			c = CarroBloco.new().configurar_modelo(base, cor, faixas_pintura.get(id, {}))
		_cena.add_child(c)
		_carros[id] = c
		_malhas[id] = _malhas_carroceria(c)
	atualizar(0.0)
	_tamanho = _alvo_tamanho()
	_camera.size = _tamanho
	_mirar()


func duracao() -> float:
	return float(_resultado.get("duracao", 0.0))


## Posições, dano e efeitos no `tempo` atual (interpolando entre amostras).
func atualizar(delta: float) -> void:
	if _amostras.is_empty():
		return
	while _i < _amostras.size() - 2 and float(_amostras[_i + 1]["t"]) <= tempo:
		_i += 1
	var a: Dictionary = _amostras[_i]
	var b: Dictionary = _amostras[mini(_i + 1, _amostras.size() - 1)]
	var span := float(b["t"]) - float(a["t"])
	var u := clampf((tempo - float(a["t"])) / span, 0.0, 1.0) if span > 0.0 else 1.0
	for id in _carros:
		var sa: Dictionary = a[id]
		var sb: Dictionary = b[id]
		var p: Vector2 = sa["pos"].lerp(sb["pos"], u)
		var c: Node3D = _carros[id]
		c.position = Vector3(p.x, _forma.altura(p), -p.y)
		var rumo := lerp_angle(float(sa["rumo"]), float(sb["rumo"]), u)
		c.rotation.y = rumo
		# Chão irregular: o carro inclina com ele (frente sobe na subida; o lado
		# mais alto do terreno levanta o lado do carro).
		var g := _forma.gradiente(p)
		var f := Vector2.from_angle(rumo)
		c.rotation.z = atan(g.dot(f))
		c.rotation.x = atan(g.dot(Vector2(-f.y, f.x)))
		_mostrar_dano(id, sb["dano"], bool(sb["eliminado"]))
	_eventos(delta)
	if delta > 0.0:
		_tamanho = lerpf(_tamanho, _alvo_tamanho(), 1.0 - exp(-delta * CAMERA_SUAVE))
		_camera.size = _tamanho
		_tremor = maxf(_tremor - delta, 0.0)
		if not Preferencias.reduzir_animacoes:
			_orbita = fmod(_orbita + delta * TAU / ORBITA_S, TAU)
	_mirar()


## Enquadramento: os vivos (todos, se já acabou), com folga, dentro da arena.
func _alvo_tamanho() -> float:
	var pts := []
	var ultima: Dictionary = _amostras[_i] if not _amostras.is_empty() else {}
	for id in _carros:
		if not ultima.is_empty() and not ultima[id]["eliminado"]:
			pts.append(_carros[id].position)
	if pts.size() < 2:
		pts = _carros.values().map(func(c): return c.position)
	# Seu carro vivo: o quadro é a sua briga (você e o rival mais perto), perto
	# o bastante para a arena ter volume; fora da luta, volta para todos.
	if _carros.has("jogador") and not ultima.is_empty() and not ultima["jogador"]["eliminado"] and pts.size() > 2:
		var eu: Vector3 = _carros["jogador"].position
		var perto := Vector3.INF
		for id in _carros:
			if id != "jogador" and not ultima[id]["eliminado"] \
					and eu.distance_to(_carros[id].position) < eu.distance_to(perto):
				perto = _carros[id].position
		var alvo_eu := eu if perto == Vector3.INF else eu.lerp(perto, 0.4)
		_centro = _centro.lerp(alvo_eu, 0.15) if _centro != Vector3.ZERO else alvo_eu
		var dist := 0.0 if perto == Vector3.INF else eu.distance_to(perto)
		# A câmera gira: os dois podem ficar na horizontal, a mais estreita no
		# celular em pé; o quadro cabe pela proporção.
		var asp := float(size.y) / maxf(float(size.x), 1.0) if size.x > 0 else 1.6
		return clampf((dist + FOLGA_M * 2.0) * maxf(asp, 1.0), TAMANHO_MIN, TAMANHO_BRIGA_MAX)
	# Destroços perto da briga também (são obstáculos no caminho).
	var meio := Vector3.ZERO
	for p in pts:
		meio += p / pts.size()
	for id in _carros:
		var p: Vector3 = _carros[id].position
		if not p in pts and p.distance_to(meio) < DESTROCO_PERTO_M:
			pts.append(p)
	var mn := Vector3(INF, 0, INF)
	var mx := Vector3(-INF, 0, -INF)
	for p in pts:
		mn = Vector3(minf(mn.x, p.x), 0, minf(mn.z, p.z))
		mx = Vector3(maxf(mx.x, p.x), 0, maxf(mx.z, p.z))
	var alvo_c := (mn + mx) * 0.5
	_centro = _centro.lerp(alvo_c, 0.08) if _centro != Vector3.ZERO else alvo_c
	# Câmera ortográfica mantém a altura: o vertical da tela é o tamanho; o
	# horizontal (mais estreito no celular) precisa caber pela proporção.
	var aspecto := float(size.y) / maxf(float(size.x), 1.0) if size.x > 0 else 1.6
	var alto := maxf(mx.z - mn.z, (mx.x - mn.x) * aspecto) + FOLGA_M * 2.0
	return clampf(alto, TAMANHO_MIN, _raio * 1.8)


func _mirar() -> void:
	var tremor := Vector3.ZERO
	if _tremor > 0.0 and not Preferencias.reduzir_animacoes:
		tremor = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.5 * _tremor
	var c := _centro + tremor
	# _tamanho é a altura do quadro no chão: a distância que mostra isso no FOV.
	var d := _tamanho * 0.5 / tan(deg_to_rad(FOV_GRAUS) * 0.5)
	var elev := deg_to_rad(ELEVACAO_GRAUS)
	var h := Vector3(sin(_orbita), 0.0, cos(_orbita))
	_camera.look_at_from_position(c + (h * cos(elev) + Vector3.UP * sin(elev)) * d, c, Vector3.UP)


# --- Dano -----------------------------------------------------------------------

## Uma marca por região (Arena.REGIOES), no ponto do carro: frente/lado/trás e
## esquerda/direita. Frente em +X, esquerda em -Z (o +Y do plano da arena).
## Amassado de verdade: a malha da carroceria afunda na região atingida, na
## proporção do estágio de dano (as seis regiões da simulação), com um enrugado
## irregular e sombreamento facetado. Rodas ficam de fora.
## Região: centro no carro (+X frente, -Z esquerda, em frações de comprimento,
## altura em m e largura), direção do afundamento e raio (fração do comprimento).
const AMASSADOS := [
	{"c": Vector3(0.5, 0.6, -0.32), "dir": Vector3(-1.0, -0.3, 0.4), "raio": 0.42, "prof": 0.8},  # frente_e
	{"c": Vector3(0.5, 0.6, 0.32), "dir": Vector3(-1.0, -0.3, -0.4), "raio": 0.42, "prof": 0.8},  # frente_d
	{"c": Vector3(0.05, 0.65, -0.5), "dir": Vector3(0.0, -0.2, 1.0), "raio": 0.34, "prof": 0.55},  # lado_e
	{"c": Vector3(0.05, 0.65, 0.5), "dir": Vector3(0.0, -0.2, -1.0), "raio": 0.34, "prof": 0.55},  # lado_d
	{"c": Vector3(-0.5, 0.6, -0.32), "dir": Vector3(1.0, -0.3, 0.4), "raio": 0.4, "prof": 0.7},  # tras_e
	{"c": Vector3(-0.5, 0.6, 0.32), "dir": Vector3(1.0, -0.3, -0.4), "raio": 0.4, "prof": 0.7},  # tras_d
]


func _malhas_carroceria(c: Node3D) -> Array:
	var partes := []
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or _e_roda(mi, c) or mi.top_level:
			continue
		var surfs := []
		for k in mi.mesh.get_surface_count():
			var prim: int = mi.mesh.surface_get_primitive_type(k) if mi.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
			if prim != Mesh.PRIMITIVE_TRIANGLES:
				surfs = []
				break
			surfs.append({"arr": mi.mesh.surface_get_arrays(k), "prim": prim, "mat": mi.mesh.surface_get_material(k)})
		if not surfs.is_empty():
			partes.append({"mi": mi, "rel": _relativo(c, mi), "surfs": surfs})
	return partes


static func _e_roda(n: Node, raiz: Node) -> bool:
	while n != null and n != raiz:
		if String(n.name).begins_with("roda"):
			return true
		n = n.get_parent()
	return false


## Transformação de `n` no espaço de `raiz` (sem depender da árvore global).
static func _relativo(raiz: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var no: Node = n
	while no != null and no != raiz:
		if no is Node3D:
			t = (no as Node3D).transform * t
		no = no.get_parent()
	return t


## Refaz a malha da carroceria com o estágio de cada região (só quando muda).
func _amassar(id: String, estagios: PackedInt32Array, eliminado: bool) -> void:
	var c: Node3D = _carros[id]
	var dim: Vector2 = c.dimensoes() if c.has_method("dimensoes") else Vector2(Arena.COMPRIMENTO_M, Arena.LARGURA_M)
	var fator := []
	for r in AMASSADOS.size():
		fator.append(float(estagios[r]) / maxf(_estagios, 1) * (1.15 if eliminado else 1.0))
	for parte in _malhas.get(id, []):
		var rel: Transform3D = parte["rel"]
		var inv := rel.affine_inverse()
		var nova := ArrayMesh.new()
		for sf in parte["surfs"]:
			var arr: Array = (sf["arr"] as Array).duplicate()
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var out := PackedVector3Array()
			out.resize(vs.size())
			for i in vs.size():
				var p := rel * vs[i]
				p += _deslocamento(p, fator, dim)
				out[i] = inv * p
			arr[Mesh.ARRAY_VERTEX] = out
			# Facetado: sem índices, normais por face (o estilo low-poly chapado).
			var st := SurfaceTool.new()
			st.create_from_arrays(arr, sf["prim"])
			st.deindex()
			st.generate_normals()
			st.commit(nova)
			if sf["mat"] != null:
				nova.surface_set_material(nova.get_surface_count() - 1, sf["mat"])
		(parte["mi"] as MeshInstance3D).mesh = nova


static func _deslocamento(p: Vector3, fator: Array, dim: Vector2) -> Vector3:
	var d := Vector3.ZERO
	for r in AMASSADOS.size():
		var f: float = fator[r]
		if f <= 0.0:
			continue
		var a: Dictionary = AMASSADOS[r]
		var centro := Vector3(a["c"].x * dim.x, a["c"].y, a["c"].z * dim.y)
		var raio: float = a["raio"] * dim.x
		var dist := p.distance_to(centro)
		if dist >= raio:
			continue
		var u := 1.0 - dist / raio
		# Enrugado: cada vértice afunda um pouco diferente (fixo pela posição).
		var ruga := 0.45 + 0.55 * absf(sin(p.x * 13.1 + p.y * 9.7 + p.z * 7.3) + 0.5 * sin(p.x * 31.0 - p.z * 23.0))
		d += (a["dir"] as Vector3).normalized() * a["prof"] * f * u * sqrt(u) * ruga
	return d


func _mostrar_dano(id: String, dano: PackedFloat32Array, eliminado: bool) -> void:
	var pior := 0.0
	var est := PackedInt32Array()
	for r in dano.size():
		est.append(Arena.estagio(dano[r], _estagios) + 1 if dano[r] > 0.0 else 0)
		pior = maxf(pior, dano[r])
	if eliminado:
		est.append(1)
	if _estagio_visto.get(id, PackedInt32Array()) != est:
		_estagio_visto[id] = est
		_amassar(id, est, eliminado)
	var c: Node3D = _carros[id]
	var tom := Color(0.32, 0.3, 0.3) if eliminado else Color.WHITE.lerp(Color(0.75, 0.72, 0.7), pior)
	_tingir(c, tom)
	var fumando := eliminado or Arena.estagio(pior, _estagios) >= FUMACA_ESTAGIO
	if fumando and not _fumaca.has(id) and not Preferencias.efeitos_leves:
		_fumaca[id] = _criar_fumaca(c, eliminado)
	if _fumaca.has(id) and eliminado and not _fumaca[id].get_meta("preta", false):
		_fumaca[id].queue_free()
		_fumaca[id] = _criar_fumaca(c, true)


func _tingir(n: Node, tom: Color) -> void:
	for f in n.get_children():
		if f is SpriteBase3D and not f.top_level:
			f.modulate = Color(tom, f.modulate.a)
		elif f is GeometryInstance3D and f.material_override is ShaderMaterial:
			pass
		_tingir(f, tom)


func _criar_fumaca(c: Node3D, preta: bool) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 16 if preta else 12
	f.lifetime = 1.6
	f.local_coords = false
	f.direction = Vector3.UP
	f.spread = 18.0
	f.initial_velocity_min = 1.2
	f.initial_velocity_max = 2.4
	f.gravity = Vector3(0.6, 0.4, 0.0)  # deriva com o vento
	f.scale_amount_min = 0.6
	f.scale_amount_max = 1.8
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _textura_amassado()
	m.render_priority = 35
	q.material = m
	f.mesh = q
	var cores := Gradient.new()
	# Eliminado: fumaça cinza-chumbo e rala (preta e densa virava uma bola
	# escura sobre o capô, vista de cima).
	var base := Color(0.32, 0.31, 0.3) if preta else Color(0.75, 0.74, 0.72)
	cores.set_color(0, Color(base, 0.0))
	cores.add_point(0.25, Color(base, 0.3))
	cores.set_color(cores.get_point_count() - 1, Color(base, 0.0))
	f.color_ramp = cores
	f.position = Vector3(Arena.COMPRIMENTO_M * 0.3, 1.4, 0.0)  # do capô (motor na frente), já acima dele
	f.set_meta("preta", preta)
	c.add_child(f)
	f.emitting = true
	return f


## Batidas novas até o tempo atual: faíscas no carro atingido e um tranco.
func _eventos(_delta: float) -> void:
	var evs: Array = _resultado.get("eventos", [])
	while _eventos_vistos < evs.size() and float(evs[_eventos_vistos]["t"]) <= tempo:
		var e: Dictionary = evs[_eventos_vistos]
		_eventos_vistos += 1
		if e["tipo"] != "impacto" or not _carros.has(e["carro"]):
			continue
		var forte := float(e["dano"]) > 0.08
		if forte:
			_tremor = minf(_tremor + float(e["dano"]) * 2.0, 0.6)
		_faiscas(_carros[e["carro"]].global_position + Vector3(0, 0.8, 0), forte)


func _faiscas(onde: Vector3, forte: bool) -> void:
	if Preferencias.efeitos_leves:
		return
	var f := CPUParticles3D.new()
	f.one_shot = true
	f.amount = 30 if forte else 12
	f.lifetime = 0.5
	f.explosiveness = 1.0
	f.direction = Vector3.UP
	f.spread = 80.0
	f.initial_velocity_min = 5.0
	f.initial_velocity_max = 14.0 if forte else 8.0
	f.gravity = Vector3(0, -22, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.2)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.render_priority = 40
	q.material = m
	f.mesh = q
	var cores := Gradient.new()
	cores.set_color(0, Color(1.0, 0.95, 0.7))
	cores.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	f.color_ramp = cores
	f.position = onde
	_cena.add_child(f)
	f.emitting = true
	get_tree().create_timer(1.0).timeout.connect(f.queue_free)


static var _amassado: Texture2D


## Mancha irregular (amassado/fuligem): radial com borda quebrada, procedural.
static func _textura_amassado() -> Texture2D:
	if _amassado != null:
		return _amassado
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in n:
		for x in n:
			var d := Vector2(x - n / 2.0, y - n / 2.0).length() / (n / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = smoothstep(0.0, 0.6, a) * (0.7 + 0.3 * rng.randf())
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_amassado = ImageTexture.create_from_image(img)
	return _amassado


# --- Cenário ---------------------------------------------------------------------

## Chão de terra batida (disco), muro de pneus empilhados no raio e um anel de
## concreto por fora.
func _construir_arena() -> void:
	_chao()
	_pneus_muro()
	_ilhas()


## Chão em malha com o relevo da arena (lombadas, crateras, a borda que sobe
## para o muro), na textura de terra; a luz baixa marca as encostas.
func _chao() -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q in _forma.muro:
		mn = mn.min(q)
		mx = mx.max(q)
	mn -= Vector2.ONE * CHAO_MARGEM_M
	mx += Vector2.ONE * CHAO_MARGEM_M
	var nx := int(ceil((mx.x - mn.x) / CHAO_PASSO_M))
	var ny := int(ceil((mx.y - mn.y) / CHAO_PASSO_M))
	var alturas := PackedFloat32Array()
	alturas.resize((nx + 1) * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			alturas[j * (nx + 1) + i] = _forma.altura(mn + Vector2(i, j) * CHAO_PASSO_M)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ny:
		for i in nx:
			var cantos := [[i, j], [i + 1, j], [i, j + 1], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			for k in [0, 2, 1, 3, 5, 4]:
				var ci: int = cantos[k][0]
				var cj: int = cantos[k][1]
				var q := mn + Vector2(ci, cj) * CHAO_PASSO_M
				var h: float = alturas[cj * (nx + 1) + ci]
				# Luz pré-calculada pela inclinação (a encosta virada para a luz
				# clareia, a outra escurece) e o fundo um pouco mais escuro.
				var gx := (alturas[cj * (nx + 1) + mini(ci + 1, nx)] - alturas[cj * (nx + 1) + maxi(ci - 1, 0)]) / (2.0 * CHAO_PASSO_M)
				var gy := (alturas[mini(cj + 1, ny) * (nx + 1) + ci] - alturas[maxi(cj - 1, 0) * (nx + 1) + ci]) / (2.0 * CHAO_PASSO_M)
				var nrm := Vector3(-gx, 1.0, gy).normalized()
				var luz := clampf(0.62 + 0.55 * nrm.dot(LUZ_CHAO), 0.45, 1.25) * clampf(1.0 + h * 0.035, 0.8, 1.1)
				st.set_color(Color(luz, luz, luz))
				st.set_uv(q / 7.0)
				st.add_vertex(Vector3(q.x, h, -q.y))
	st.generate_normals()
	var chao := MeshInstance3D.new()
	chao.mesh = st.commit()
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	var asfalto := MontadorPista.kit("asfalto_b")
	if asfalto != null:
		mt.albedo_texture = asfalto
		mt.albedo_color = Color(0.85, 0.74, 0.6)
	else:
		mt.albedo_color = Color(0.36, 0.3, 0.24)
	mt.roughness = 0.95
	chao.material_override = mt
	_cena.add_child(chao)
	var fora := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(1000, 1000)
	fora.mesh = plano
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(0.2, 0.19, 0.18)
	fora.material_override = mf
	var fundo := 0.0
	for h in alturas:
		fundo = minf(fundo, h)
	fora.position.y = fundo - 1.0  # abaixo do fundo das crateras
	_cena.add_child(fora)


## Pneus em duas fileiras seguindo o muro (polígono), no chão de cada ponto,
## com uma faixa de cor a cada tanto.
func _pneus_muro() -> void:
	var pontos := []  # [posição 3D, colorido]
	var n := _forma.muro.size()
	var k := 0
	for i in n:
		var a := _forma.muro[i]
		var b := _forma.muro[(i + 1) % n]
		var fora := (b - a).normalized().orthogonal()  # o lado de fora (direita da aresta anti-horária)
		var passos := maxi(int((b - a).length() * PNEUS_POR_M / 1.2), 1)
		for camada in 2:
			for t in passos:
				var q := a.lerp(b, (float(t) + 0.5 * camada) / passos) + fora * (0.7 + camada * 1.15)
				pontos.append([Vector3(q.x, _forma.altura(q) + 0.18, -q.y), k % 9 == 0])
				k += 1
	for o in _forma.obstaculos:
		var r: float = o["r"]
		var voltas := int(TAU * r * PNEUS_POR_M / 1.2)
		for camada in 2:
			for t in voltas:
				var q: Vector2 = o["c"] + Vector2.from_angle(TAU * (t + 0.5 * camada) / voltas) * (r - 0.6)
				pontos.append([Vector3(q.x, _forma.altura(q) + 0.18 + camada * 0.36, -q.y), t % 7 == 0])
	var pneu := CylinderMesh.new()
	pneu.top_radius = 0.6
	pneu.bottom_radius = 0.6
	pneu.height = 0.36
	pneu.radial_segments = 10
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = pneu
	mm.instance_count = pontos.size()
	for i in pontos.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pontos[i][0]))
		mm.set_instance_color(i, Color(0.75, 0.2, 0.12) if pontos[i][1] else Color(0.07, 0.07, 0.08))
	var pneus := MultiMeshInstance3D.new()
	pneus.multimesh = mm
	var mp := StandardMaterial3D.new()
	mp.vertex_color_use_as_albedo = true
	mp.roughness = 0.9
	pneus.material_override = mp
	_cena.add_child(pneus)


## Ilhas: um monte de entulho escuro dentro do anel de pneus de cada obstáculo.
func _ilhas() -> void:
	for o in _forma.obstaculos:
		var r: float = o["r"]
		var m := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = r * 0.35
		cone.bottom_radius = r - 0.9
		cone.height = 1.6 + r * 0.12
		cone.radial_segments = 9
		m.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.24, 0.21, 0.19)
		mat.roughness = 1.0
		m.material_override = mat
		var c: Vector2 = o["c"]
		m.position = Vector3(c.x, _forma.altura(c) + cone.height * 0.5, -c.y)
		_cena.add_child(m)
