class_name Corrida3D
extends SubViewportContainer
## Corrida em 3D com carros de blocos, câmera isométrica seguindo o jogador.
## Lê as distâncias de uma CorridaVisual (o minimapa) e não decide nada: o
## resultado já veio da Simulacao.
##
## A simulação é em uma dimensão (distância percorrida). A posição lateral é
## só visual: quem está a menos de PROXIMIDADE_M de outro carro abre para uma
## faixa livre, então os carros não se atravessam; na ultrapassagem ficam lado
## a lado. Se dois carros chegam a se tocar na troca de faixa, o contato
## aparece como um tranco no carro (sem efeito no resultado).

const LARGURA_PISTA_M := 12.0
const FAIXAS_M := [0.0, 2.1, -2.1, 4.2, -4.2]
const PROXIMIDADE_M := 5.5
const VELOCIDADE_LATERAL := 3.0  # 1/s, aproximação da faixa-alvo
const TAMANHO_CAMERA := 36.0
const ALTURA_MARCADOR := 2.6

var _fonte: CorridaVisual
var _pista: Pista
var _mundo: Node3D
var _cena: Node3D
var _camera: Camera3D
var _carros := {}  # id -> CarroBloco
var _rotulos := {}  # id -> Label3D
var _lateral := {}  # id -> deslocamento atual (m, + = esquerda)
var _s_anterior := {}
var _tranco := {}  # id -> segundos restantes de tranco
var _alvo_camera := Vector3.ZERO


func _init() -> void:
	stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	_mundo = Node3D.new()
	vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.42, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	amb.environment = env
	_mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-1.0, 0.5, 0)
	_mundo.add_child(luz)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = TAMANHO_CAMERA
	_camera.far = 600.0
	_mundo.add_child(_camera)
	_cena = Node3D.new()
	_mundo.add_child(_cena)


## categorias: id -> categoria do carro (CarroBloco.FORMAS).
func mostrar(pista: Pista, fonte: CorridaVisual, categorias: Dictionary) -> void:
	limpar()
	_pista = pista
	_fonte = fonte
	_construir_pista()
	for id in fonte.ordem():
		var c := CarroBloco.new().configurar(categorias.get(id, "seda"), fonte.cor_de(id))
		_cena.add_child(c)
		_carros[id] = c
		var r := Label3D.new()
		r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		r.no_depth_test = true
		r.pixel_size = 0.045
		r.font_size = 48
		r.outline_size = 14
		r.modulate = fonte.cor_de(id).lightened(0.3)
		_cena.add_child(r)
		_rotulos[id] = r
		_lateral[id] = 0.0
	atualizar(0.0)
	_camera_imediata()


func limpar() -> void:
	for c in _cena.get_children():
		c.queue_free()
	_carros = {}
	_rotulos = {}
	_lateral = {}
	_s_anterior = {}
	_tranco = {}
	_pista = null


## Posiciona os carros no tempo atual da fonte. delta suaviza a troca de faixa.
func atualizar(delta: float) -> void:
	if _pista == null:
		return
	var s := {}
	for id in _carros:
		s[id] = _fonte.distancia(id)
	var ordem := _fonte.ordem()
	var alvo := faixas(ordem, s, _lateral, _pista.comprimento)
	var k := clampf(delta * VELOCIDADE_LATERAL, 0.0, 1.0) if delta > 0.0 else 1.0
	var antes := _lateral.duplicate()
	for id in _carros:
		_lateral[id] = lerpf(_lateral[id], alvo[id], k)
	for par in contatos(ordem, s, _lateral, _pista.comprimento):
		for id in par:
			_tranco[id] = 0.35
	for i in ordem.size():
		var id: String = ordem[i]
		var c: CarroBloco = _carros[id]
		var dist: float = s[id]
		var rumo := _pista.rumo_em(dist)
		var normal := Vector2.from_angle(rumo + PI / 2.0)
		var p := _pista.posicao_em(dist) + normal * float(_lateral[id])
		c.position = Vector3(p.x, 0.0, -p.y)
		# Esterço visual da troca de faixa: ângulo entre o avanço e o desvio.
		var ds: float = dist - float(_s_anterior.get(id, dist))
		var dl: float = float(_lateral[id]) - float(antes[id])
		var esterco := clampf(atan2(dl, maxf(ds, 0.05)), -0.35, 0.35) if delta > 0.0 else 0.0
		var t: float = _tranco.get(id, 0.0)
		if t > 0.0:
			esterco += sin(t * 60.0) * 0.08
			_tranco[id] = maxf(t - delta, 0.0)
		c.rotation.y = rumo + esterco
		_s_anterior[id] = dist
		var r: Label3D = _rotulos[id]
		r.text = str(i + 1)
		r.position = c.position + Vector3(0, ALTURA_MARCADOR, 0)
	var foco: String = "jogador" if _carros.has("jogador") else (ordem[0] if not ordem.is_empty() else "")
	if foco != "":
		var novo: Vector3 = _carros[foco].position
		_alvo_camera = novo if delta <= 0.0 or _alvo_camera.distance_to(novo) > 40.0 \
				else _alvo_camera.lerp(novo, clampf(delta * 5.0, 0.0, 1.0))
		_camera_imediata()


func _camera_imediata() -> void:
	_camera.look_at_from_position(_alvo_camera + Vector3(70, 80, 70), _alvo_camera)


## Faixa lateral de cada carro: o da frente mantém a sua; quem está a menos de
## PROXIMIDADE_M (na mesma volta ou não) de um carro já posicionado vai para a
## faixa livre mais perto da atual, preferindo o traçado ideal (0).
static func faixas(ordem: Array, s: Dictionary, atual: Dictionary, comprimento: float) -> Dictionary:
	var r := {}
	for id in ordem:
		var cands: Array = FAIXAS_M.slice(1)
		var a: float = atual.get(id, 0.0)
		cands.sort_custom(func(x, y): return absf(x - a) < absf(y - a))
		cands.push_front(0.0)
		var escolhida: float = cands[0]
		for f in cands:
			var livre := true
			for outro in r:
				if _perto(s[id], s[outro], comprimento, PROXIMIDADE_M) and absf(f - r[outro]) < 2.0:
					livre = false
					break
			if livre:
				escolhida = f
				break
		r[id] = escolhida
	return r


## Pares de carros que se tocam agora: sobrepostos no comprido e no lado.
static func contatos(ordem: Array, s: Dictionary, lateral: Dictionary, comprimento: float) -> Array:
	var r := []
	for i in ordem.size():
		for j in range(i + 1, ordem.size()):
			var a: String = ordem[i]
			var b: String = ordem[j]
			if _perto(s[a], s[b], comprimento, 4.2) and absf(float(lateral[a]) - float(lateral[b])) < 1.75:
				r.append([a, b])
	return r


static func _perto(sa: float, sb: float, comprimento: float, limite: float) -> bool:
	var d := fposmod(sa - sb, comprimento)
	return minf(d, comprimento - d) < limite


func _construir_pista() -> void:
	var pts := _pista.pontos(3.0)
	var caixa := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		caixa = caixa.expand(p)
	var grama := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = caixa.size + Vector2(400, 400)
	grama.mesh = plano
	grama.material_override = CarroBloco._material(Color(0.22, 0.45, 0.25))
	var centro := caixa.get_center()
	grama.position = Vector3(centro.x, -0.06, -centro.y)
	_cena.add_child(grama)
	_cena.add_child(_faixa(pts, LARGURA_PISTA_M + 2.0, -0.03, Color(0.88, 0.88, 0.88)))
	_cena.add_child(_faixa(pts, LARGURA_PISTA_M, 0.0, Color(0.32, 0.33, 0.36)))
	var largada := MeshInstance3D.new()
	var caixa_l := BoxMesh.new()
	caixa_l.size = Vector3(1.0, 0.02, LARGURA_PISTA_M)
	largada.mesh = caixa_l
	largada.material_override = CarroBloco._material(Color.WHITE)
	var p0 := _pista.posicao_em(0.0)
	largada.position = Vector3(p0.x, 0.01, -p0.y)
	largada.rotation.y = _pista.rumo_em(0.0)
	_cena.add_child(largada)


static func _faixa(pts: PackedVector2Array, largura: float, y: float, cor: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var n := pts.size()
	var bordas := []
	for i in n:
		var antes := pts[maxi(i - 1, 0)]
		var depois := pts[mini(i + 1, n - 1)]
		var normal := (depois - antes).normalized().orthogonal() * largura * 0.5
		bordas.append([pts[i] + normal, pts[i] - normal])
	for i in n - 1:
		var a: Array = bordas[i]
		var b: Array = bordas[i + 1]
		var v := [a[0], a[1], b[0], b[1]].map(func(p): return Vector3(p.x, y, -p.y))
		for idx in [0, 2, 1, 1, 2, 3]:
			st.add_vertex(v[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := CarroBloco._material(cor)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi
