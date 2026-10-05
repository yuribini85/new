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
## Carro que a câmera segue ("jogador" por padrão). Se não existir, o jogador.
var foco := "jogador"
## Pista inteira na tela em vez de seguir um carro.
var visao_geral := false
var _centro_pista := Vector3.ZERO
var _ambiente: Environment

## Ambiente de cada pista (placeholder): cor do chão, do céu e o que fica em
## volta. Pista sem tema usa o padrão.
const TEMAS := {
	"anel_do_vale": {"chao": Color(0.24, 0.47, 0.26), "ceu": Color(0.42, 0.62, 0.78), "props": "arvores"},
	"parque_das_docas": {"chao": Color(0.36, 0.37, 0.4), "ceu": Color(0.55, 0.6, 0.68), "props": "cidade"},
	"serra_alta": {"chao": Color(0.38, 0.4, 0.26), "ceu": Color(0.62, 0.7, 0.8), "props": "serra"},
}
const TEMA_PADRAO := {"chao": Color(0.22, 0.45, 0.25), "ceu": Color(0.4, 0.6, 0.75), "props": "arvores"}
var _tamanho_geral := 200.0


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
	_ambiente = env
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


## modelos: id -> dados do carro (data/carros.json), para a silhueta de cada um.
func mostrar(pista: Pista, fonte: CorridaVisual, modelos: Dictionary) -> void:
	limpar()
	_pista = pista
	_fonte = fonte
	_construir_pista()
	for id in fonte.ordem():
		var c := CarroBloco.new().configurar_modelo(modelos.get(id, {"id": id, "categoria": "seda"}), fonte.cor_de(id))
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
	var k := clampf(delta * VELOCIDADE_LATERAL, 0.0, 1.0) if delta > 0.0 and not Preferencias.reduzir_animacoes else 1.0
	var antes := _lateral.duplicate()
	for id in _carros:
		_lateral[id] = lerpf(_lateral[id], alvo[id], k)
	for par in ([] if Preferencias.reduzir_animacoes else contatos(ordem, s, _lateral, _pista.comprimento)):
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
		c.girar_rodas(maxf(ds, 0.0))
		_s_anterior[id] = dist
		var r: Label3D = _rotulos[id]
		r.text = str(i + 1)
		r.position = c.position + Vector3(0, ALTURA_MARCADOR, 0)
	# Na visão geral, carros e números maiores para continuarem visíveis.
	var escala := maxf(1.0, _tamanho_geral / TAMANHO_CAMERA * 0.35) if visao_geral else 1.0
	for id in _carros:
		_carros[id].scale = Vector3.ONE * escala
		_rotulos[id].pixel_size = 0.045 * (escala * 1.6 if visao_geral else 1.0)
		_rotulos[id].position = _carros[id].position + Vector3(0, ALTURA_MARCADOR * escala, 0)
	if visao_geral:
		_camera.size = _tamanho_geral
		_alvo_camera = _centro_pista
		_camera_imediata()
		return
	_camera.size = TAMANHO_CAMERA
	var seguido: String = foco if _carros.has(foco) else ("jogador" if _carros.has("jogador") else (ordem[0] if not ordem.is_empty() else ""))
	if seguido != "":
		var novo: Vector3 = _carros[seguido].position
		_alvo_camera = novo if delta <= 0.0 or Preferencias.reduzir_animacoes or _alvo_camera.distance_to(novo) > 40.0 \
				else _alvo_camera.lerp(novo, clampf(delta * 5.0, 0.0, 1.0))
		_camera_imediata()


func _camera_imediata() -> void:
	# 30° acima do chão: o mesmo 2:1 da projeção Iso do minimapa.
	_camera.look_at_from_position(_alvo_camera + Vector3(70, 57.15, 70), _alvo_camera)


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
	# Enquadramento da visão geral: extensão do traçado na projeção da câmera
	# (a mesma do minimapa) e a proporção da tela.
	var proj := Rect2(Iso.para_tela(pts[0], 1.0), Vector2.ZERO)
	for p in pts:
		proj = proj.expand(Iso.para_tela(p, 1.0))
	var aspecto := size.x / maxf(size.y, 1.0) if size.y > 0.0 else 1.4
	_tamanho_geral = maxf(proj.size.y, proj.size.x / aspecto) / sqrt(2.0) * 1.15 + 20.0
	var c_tela := proj.get_center()
	# Inverso de Iso.para_tela: x + y = cx, (x - y)/2 = cy.
	var meio := Vector2((c_tela.x + 2.0 * c_tela.y) * 0.5, (c_tela.x - 2.0 * c_tela.y) * 0.5)
	_centro_pista = Vector3(meio.x, 0.0, -meio.y)
	var tema: Dictionary = TEMAS.get(_pista.id, TEMA_PADRAO)
	_ambiente.background_color = tema["ceu"]
	var grama := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = caixa.size + Vector2(400, 400)
	grama.mesh = plano
	grama.material_override = CarroBloco._material(tema["chao"])
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
	_arquibancada()
	_decorar(pts, tema["props"])


## Arquibancada ao lado da largada: referência para saber onde a volta começa.
func _arquibancada() -> void:
	var p0 := _pista.posicao_em(0.0)
	var rumo := _pista.rumo_em(0.0)
	var lado := Vector2.from_angle(rumo + PI / 2.0)
	var base := p0 + lado * (LARGURA_PISTA_M * 0.5 + 8.0)
	for degrau in 4:
		var b := _bloco(Vector3(30.0, 1.2, 3.0), Color(0.75, 0.2, 0.2) if degrau % 2 == 0 else Color(0.9, 0.9, 0.9))
		var q := base + lado * (degrau * 3.0)
		b.position = Vector3(q.x, 0.6 + degrau * 1.2, -q.y)
		b.rotation.y = rumo
		_cena.add_child(b)


## Objetos em volta da pista, longe do asfalto, sempre no mesmo lugar para a
## mesma pista (semente pelo id).
func _decorar(pts: PackedVector2Array, tipo: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_pista.id)
	var amostra := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		amostra.append(pts[i])
	var colocados := 0
	for tentativa in 400:
		if colocados >= 110:
			break
		var s := rng.randf() * _pista.comprimento
		var rumo := _pista.rumo_em(s)
		var lado := 1.0 if rng.randf() < 0.5 else -1.0
		var dist := rng.randf_range(16.0, 70.0)
		var p := _pista.posicao_em(s) + Vector2.from_angle(rumo + PI / 2.0) * lado * dist
		var livre := true
		for q in amostra:
			if p.distance_squared_to(q) < 14.0 * 14.0:
				livre = false
				break
		if not livre:
			continue
		colocados += 1
		var n := _objeto(tipo, rng)
		n.position.x = p.x
		n.position.z = -p.y
		n.rotation.y = rng.randf() * TAU
		_cena.add_child(n)


func _objeto(tipo: String, rng: RandomNumberGenerator) -> Node3D:
	match tipo:
		"cidade":
			if rng.randf() < 0.35:
				var cont := _bloco(Vector3(6.0, 2.6, 2.4), [Color(0.8, 0.3, 0.2), Color(0.2, 0.45, 0.7), Color(0.85, 0.65, 0.2)][rng.randi() % 3])
				cont.position.y = 1.3
				return cont
			var h := rng.randf_range(6.0, 22.0)
			var predio := _bloco(Vector3(rng.randf_range(8.0, 14.0), h, rng.randf_range(8.0, 14.0)),
					Color(0.5, 0.52, 0.56).lerp(Color(0.7, 0.62, 0.52), rng.randf()))
			predio.position.y = h * 0.5
			return predio
		"serra":
			if rng.randf() < 0.4:
				var pedra := _bloco(Vector3.ONE * rng.randf_range(2.0, 5.0), Color(0.45, 0.43, 0.4))
				pedra.position.y = 0.8
				return pedra
			return _arvore(rng, Color(0.16, 0.32, 0.2), 1.3)
	return _arvore(rng, Color(0.2, 0.5, 0.25), 1.0)


func _arvore(rng: RandomNumberGenerator, cor: Color, alongar: float) -> Node3D:
	var n := Node3D.new()
	var tronco := _bloco(Vector3(0.6, 2.0, 0.6), Color(0.4, 0.28, 0.18))
	tronco.position.y = 1.0
	n.add_child(tronco)
	var copa := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = rng.randf_range(2.0, 3.2)
	cone.height = rng.randf_range(5.0, 8.0) * alongar
	cone.radial_segments = 7
	cone.rings = 1
	copa.mesh = cone
	copa.material_override = CarroBloco._material(cor)
	copa.position.y = 2.0 + cone.height * 0.5
	n.add_child(copa)
	return n


static func _bloco(tam: Vector3, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	mi.material_override = CarroBloco._material(cor)
	return mi


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
