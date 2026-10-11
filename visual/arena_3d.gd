class_name Arena3D
extends SubViewportContainer
## Arena de destruição em 3D, de cima (decisão 50): só lê as amostras de
## Arena.correr (a simulação já resolveu tudo). Chão de terra batida num
## círculo, muro de pneus, carros com a mesma arte da corrida (sprite ou o
## carro em código). Dano por região: marcas escuras no ponto do carro, mais
## fortes a cada estágio (Arena.estagio); fumaça a partir do 4º estágio; o
## eliminado escurece e solta fumaça preta. Faíscas e um tranco de câmera nas
## batidas. A câmera enquadra os carros ainda vivos.

const ALTURA_CAMERA := 400.0
const FOLGA_M := 9.0  # margem em volta dos carros no enquadramento
const DESTROCO_PERTO_M := 26.0  # destroço a essa distância da briga entra no quadro
const TAMANHO_MIN := 28.0
const CAMERA_SUAVE := 2.5  # 1/s
const PNEUS_POR_M := 0.95
const FUMACA_ESTAGIO := 3  # estágio (0..4) a partir do qual sai fumaça

## Tempo atual da luta (s); quem mostra avança.
var tempo := 0.0

var _resultado: Dictionary = {}
var _amostras: Array = []
var _i := 0
var _mundo: Node3D
var _cena: Node3D
var _camera: Camera3D
var _carros := {}  # id -> Node3D
var _marcas := {}  # id -> [MeshInstance3D x6]
var _fumaca := {}  # id -> CPUParticles3D
var _eventos_vistos := 0
var _estagios := 5
var _raio := 45.0
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
	env.ambient_light_color = Color(0.62, 0.6, 0.58)
	amb.environment = env
	_mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-1.0, 0.6, 0)
	luz.light_color = Color(1.0, 0.86, 0.7)
	_mundo.add_child(luz)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
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
	_marcas = {}
	_fumaca = {}
	_resultado = resultado
	_amostras = resultado.get("amostras", [])
	_estagios = int(params.get("estagios", 5))
	_raio = float(params.get("raio_m", 45.0))
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
			c = CarroBloco.new().configurar_modelo(base, cor)
		_cena.add_child(c)
		_carros[id] = c
		_marcas[id] = _criar_marcas(c)
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
		c.position = Vector3(p.x, 0.0, -p.y)
		c.rotation.y = lerp_angle(float(sa["rumo"]), float(sb["rumo"]), u)
		_mostrar_dano(id, sb["dano"], bool(sb["eliminado"]))
	_eventos(delta)
	if delta > 0.0:
		_tamanho = lerpf(_tamanho, _alvo_tamanho(), 1.0 - exp(-delta * CAMERA_SUAVE))
		_camera.size = _tamanho
		_tremor = maxf(_tremor - delta, 0.0)
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
	return clampf(alto, TAMANHO_MIN, _raio * 2.6)


func _mirar() -> void:
	var tremor := Vector3.ZERO
	if _tremor > 0.0 and not Preferencias.reduzir_animacoes:
		tremor = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.5 * _tremor
	var c := _centro + tremor
	_camera.look_at_from_position(c + Vector3.UP * ALTURA_CAMERA, c, Vector3(0, 0, -1))


# --- Dano -----------------------------------------------------------------------

## Uma marca por região (Arena.REGIOES), no ponto do carro: frente/lado/trás e
## esquerda/direita. Frente em +X, esquerda em -Z (o +Y do plano da arena).
func _criar_marcas(c: Node3D) -> Array:
	var dim: Vector2 = c.dimensoes() if c.has_method("dimensoes") else Vector2(Arena.COMPRIMENTO_M, Arena.LARGURA_M)
	var lx := dim.x * 0.36
	var lz := dim.y * 0.32
	var pontos := [Vector3(lx, 0, -lz), Vector3(lx, 0, lz), Vector3(0, 0, -lz), Vector3(0, 0, lz),
			Vector3(-lx, 0, -lz), Vector3(-lx, 0, lz)]
	var l := []
	for p in pontos:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(dim.x * 0.42, dim.y * 0.62)
		q.orientation = PlaneMesh.FACE_Y
		m.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _textura_amassado()
		mat.albedo_color = Color(0.08, 0.07, 0.06, 0.0)
		mat.render_priority = 30
		mat.no_depth_test = true
		m.material_override = mat
		m.position = p + Vector3(0, 0.9, 0)
		c.add_child(m)
		l.append(m)
	return l


func _mostrar_dano(id: String, dano: PackedFloat32Array, eliminado: bool) -> void:
	var pior := 0.0
	for r in dano.size():
		var e := Arena.estagio(dano[r], _estagios)
		var a := 0.0 if dano[r] <= 0.0 else 0.45 + 0.55 * float(e) / maxf(_estagios - 1, 1)
		(_marcas[id][r].material_override as StandardMaterial3D).albedo_color.a = a
		pior = maxf(pior, dano[r])
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
	f.amount = 22 if preta else 12
	f.lifetime = 1.6
	f.local_coords = false
	f.direction = Vector3.UP
	f.spread = 18.0
	f.initial_velocity_min = 1.2
	f.initial_velocity_max = 2.4
	f.gravity = Vector3(0.6, 0.4, 0.0)  # deriva com o vento
	f.scale_amount_min = 1.0
	f.scale_amount_max = 2.6
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
	var base := Color(0.08, 0.08, 0.09) if preta else Color(0.75, 0.74, 0.72)
	cores.set_color(0, Color(base, 0.0))
	cores.add_point(0.15, Color(base, 0.55 if preta else 0.35))
	cores.set_color(cores.get_point_count() - 1, Color(base, 0.0))
	f.color_ramp = cores
	f.position = Vector3(Arena.COMPRIMENTO_M * 0.3, 1.0, 0.0)  # do capô (motor na frente)
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
	var chao := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = _raio + 6.0
	disco.bottom_radius = _raio + 6.0
	disco.height = 0.1
	disco.radial_segments = 64
	chao.mesh = disco
	var mt := StandardMaterial3D.new()
	var asfalto := MontadorPista.kit("asfalto_b")
	if asfalto != null:
		mt.albedo_texture = asfalto
		mt.uv1_scale = Vector3(14, 14, 1)
		mt.albedo_color = Color(0.85, 0.74, 0.6)
	else:
		mt.albedo_color = Color(0.36, 0.3, 0.24)
	chao.material_override = mt
	chao.position.y = -0.06
	_cena.add_child(chao)
	var fora := MeshInstance3D.new()
	var anel := CylinderMesh.new()
	anel.top_radius = _raio + 60.0
	anel.bottom_radius = _raio + 60.0
	anel.height = 0.08
	fora.mesh = anel
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(0.2, 0.19, 0.18)
	fora.material_override = mf
	fora.position.y = -0.12
	_cena.add_child(fora)
	# Pneus: cilindros pretos lado a lado, duas camadas, com uma faixa de cor a cada tanto.
	var pneu := CylinderMesh.new()
	pneu.top_radius = 0.6
	pneu.bottom_radius = 0.6
	pneu.height = 0.36
	pneu.radial_segments = 10
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = pneu
	var volta := TAU * (_raio + 0.7)
	var n := int(volta * PNEUS_POR_M / 1.2)
	mm.instance_count = n * 2
	for k in n * 2:
		var camada := k / n
		var ang := TAU * float(k % n) / n + (0.5 * TAU / n if camada == 1 else 0.0)
		var fileira := _raio + 0.7 + camada * 1.15  # duas fileiras lado a lado
		var p := Vector3(cos(ang) * fileira, 0.18, -sin(ang) * fileira)
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, p))
		var faixa := (k % n) % 9 == 0
		mm.set_instance_color(k, Color(0.75, 0.2, 0.12) if faixa else Color(0.07, 0.07, 0.08))
	var pneus := MultiMeshInstance3D.new()
	pneus.multimesh = mm
	var mp := StandardMaterial3D.new()
	mp.vertex_color_use_as_albedo = true
	mp.roughness = 0.9
	pneus.material_override = mp
	_cena.add_child(pneus)
