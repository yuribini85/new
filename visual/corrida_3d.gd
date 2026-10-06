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
const TAMANHO_CAMERA := 28.0
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
## Cada pista com hora do dia, cores e cenário próprios, para ser
## reconhecida de relance (placeholder da arte final).
const TEMAS := {
	"anel_do_vale": {"chao": Color(0.26, 0.5, 0.25), "ceu": Color(0.45, 0.66, 0.88), "props": "arvores",
		"luz": Color(1.0, 0.97, 0.9), "energia": 1.0, "sol": Vector3(-1.05, 0.6, 0), "ambiente": Color(0.62, 0.66, 0.7),
		"asfalto": Color(0.29, 0.3, 0.33), "muro": [Color(0.92, 0.92, 0.92), Color(0.8, 0.15, 0.12)], "fundo": "colinas", "neblina": 0.0},
	"parque_das_docas": {"chao": Color(0.42, 0.41, 0.42), "ceu": Color(0.95, 0.6, 0.4), "props": "cidade",
		"luz": Color(1.0, 0.75, 0.5), "energia": 1.0, "sol": Vector3(-0.65, -0.9, 0), "ambiente": Color(0.68, 0.58, 0.62),
		"asfalto": Color(0.22, 0.22, 0.25), "muro": [Color(0.95, 0.78, 0.1), Color(0.12, 0.12, 0.14)], "fundo": "porto", "neblina": 0.0},
	"serra_alta": {"chao": Color(0.36, 0.4, 0.28), "ceu": Color(0.68, 0.73, 0.8), "props": "serra",
		"luz": Color(0.85, 0.9, 1.0), "energia": 0.7, "sol": Vector3(-0.8, 2.2, 0), "ambiente": Color(0.62, 0.66, 0.74),
		"asfalto": Color(0.34, 0.35, 0.37), "muro": [Color(0.9, 0.92, 0.95), Color(0.2, 0.38, 0.75)], "fundo": "montanhas", "neblina": 0.0},
	# Campo de provas no planalto seco: meio-dia, chão claro, mesas ao longe.
	"pista_de_testes": {"chao": Color(0.72, 0.62, 0.45), "ceu": Color(0.55, 0.75, 0.95), "props": "deserto",
		"luz": Color(1.0, 0.98, 0.92), "energia": 1.15, "sol": Vector3(-1.35, 0.3, 0), "ambiente": Color(0.7, 0.68, 0.64),
		"asfalto": Color(0.25, 0.25, 0.27), "muro": [Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.12)], "fundo": "mesas", "neblina": 0.0},
}
## Montagem pelo kit de arte (MontadorPista, docs/arte_pistas.md): texturas do
## chão, árvores, luz (tinta), direção e força das sombras, bordas da tela.
## O Anel segue a referência de estilo: autódromo na mata ao entardecer.
const KITS := {
	"anel_do_vale": {"kit": {"chao_a": "grama_a", "chao_b": "grama_b", "chao_mata": "mata", "aberto_m": 70.0, "arvores": ["arvore_1", "arvore_2",
			"arvore_3", "arvore_4", "arvore_5", "arvore_6"], "densidade": 1.0, "postes": true},
		"tinta": Color(0.8, 0.68, 0.58), "sombra_dir": Vector2(1.6, -0.9), "sombra_alfa": 0.5,
		"vinheta": 0.45, "fundo": Color(0.07, 0.09, 0.08)},
	"serra_alta": {"kit": {"chao_a": "grama_b", "chao_b": "grama_a", "chao_mata": "mata", "aberto_m": 45.0, "arvores": ["pinheiro_1", "pinheiro_2",
			"pinheiro_3"], "raras": ["rocha_1", "rocha_2"], "chance_rara": 0.06, "densidade": 0.9, "postes": false},
		"tinta": Color(0.92, 0.97, 1.05), "sombra_dir": Vector2(0.6, -0.5), "sombra_alfa": 0.4,
		"vinheta": 0.3, "fundo": Color(0.08, 0.1, 0.1)},
	"parque_das_docas": {"kit": {"chao_a": "concreto", "chao_b": "concreto", "escape": "concreto", "areia": "brita",
			"arvores": ["conteiner_1", "conteiner_2", "conteiner_3"], "densidade": 0.7, "postes": true, "alinhado": true, "altura_mata_m": 1.5,
			"agua": {"afastamento_m": 70.0}},
		"tinta": Color(1.0, 0.82, 0.7), "sombra_dir": Vector2(1.8, -1.0), "sombra_alfa": 0.5,
		"vinheta": 0.45, "fundo": Color(0.1, 0.1, 0.11)},
	"pista_de_testes": {"kit": {"chao_a": "areia", "chao_b": "brita", "escape": "areia",
			"arvores": ["rocha_1", "rocha_2", "rocha_3"], "densidade": 0.18, "postes": false},
		"tinta": Color(1.04, 1.0, 0.94), "sombra_dir": Vector2(0.4, -0.3), "sombra_alfa": 0.35,
		"vinheta": 0.25, "fundo": Color(0.45, 0.38, 0.28)},
}
const TEMA_PADRAO := {"chao": Color(0.22, 0.45, 0.25), "ceu": Color(0.4, 0.6, 0.75), "props": "arvores",
	"luz": Color.WHITE, "energia": 1.0, "sol": Vector3(-1.0, 0.5, 0), "ambiente": Color(0.6, 0.62, 0.66),
	"asfalto": Color(0.27, 0.28, 0.31), "muro": [Color(0.82, 0.82, 0.84), Color(0.2, 0.35, 0.75)], "fundo": "", "neblina": 0.0}
var _luz: DirectionalLight3D
var _cores_muro: Array = TEMA_PADRAO["muro"]
var _tamanho_geral := 200.0
var _proj := Rect2()
## Carro que o jogador persegue: anel vermelho no chão e rótulo "ALVO".
var alvo := ""
var _anel_alvo: MeshInstance3D
var _anel_jogador: MeshInstance3D
## Traço do seu carro até o alvo, quando ele está perto (disputa).
var _traco: MeshInstance3D
const DISPUTA_M := 12.0
const TAMANHO_DISPUTA := 21.0


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
	_luz = DirectionalLight3D.new()
	_luz.rotation = Vector3(-1.0, 0.5, 0)
	_mundo.add_child(_luz)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = TAMANHO_CAMERA
	_camera.far = 12000.0  # pista de 4 km na visão geral: o chão some antes de 6000
	_mundo.add_child(_camera)
	_cena = Node3D.new()
	_mundo.add_child(_cena)
	var efeito := ShaderMaterial.new()
	efeito.shader = preload("res://visual/shaders/velocidade.gdshader")
	material = efeito


## modelos: id -> dados do carro (data/carros.json), para a silhueta de cada um.
func mostrar(pista: Pista, fonte: CorridaVisual, modelos: Dictionary) -> void:
	limpar()
	_pista = pista
	_fonte = fonte
	_construir_pista()
	for id in fonte.ordem():
		var base: Dictionary = modelos.get(id, {"id": id, "categoria": "seda"})
		# Arte em sprite (decisão 31) quando o modelo tem; senão, o carro em código.
		var c: Node3D = CarroDesenho.new()
		if not c.configurar(String(base.get("id", ""))):
			c.free()
			c = CarroBloco.new().configurar_modelo(base, fonte.cor_de(id))
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
		var c: Node3D = _carros[id]
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
		if delta > 0.0:
			_v[id] = lerpf(float(_v.get(id, 0.0)), maxf(ds, 0.0) / delta, clampf(delta * 4.0, 0.0, 1.0))
		_s_anterior[id] = dist
		var r: Label3D = _rotulos[id]
		r.text = "VOCÊ" if id == "jogador" else str(i + 1)
		r.position = c.position + Vector3(0, ALTURA_MARCADOR, 0)
	# Na visão geral, carros e números maiores para continuarem visíveis.
	var escala := maxf(1.0, _tamanho_geral / TAMANHO_CAMERA * 0.35) if visao_geral else 1.0
	for id in _carros:
		_carros[id].scale = Vector3.ONE * escala
		# Números dos rivais menores e translúcidos; VOCÊ e ALVO em destaque.
		var forte: bool = id == "jogador" or id == self.alvo
		_rotulos[id].pixel_size = (0.045 if forte else 0.032) * (escala * 1.6 if visao_geral else 1.0)
		_rotulos[id].modulate.a = 1.0 if forte else 0.7
		_rotulos[id].position = _carros[id].position + Vector3(0, ALTURA_MARCADOR * escala, 0)
	var disputa := false
	if _anel_alvo != null:
		_anel_alvo.visible = _carros.has(alvo) and not visao_geral
		if _anel_alvo.visible:
			_anel_alvo.position = _carros[alvo].position + Vector3(0, 0.05, 0)
			_rotulos[alvo].text = "ALVO"
		_anel_jogador.visible = _carros.has("jogador") and not visao_geral
		if _anel_jogador.visible:
			_anel_jogador.position = _carros["jogador"].position + Vector3(0, 0.05, 0)
		# Disputa: alvo a poucos metros; traço entre os dois e câmera mais perto.
		disputa = _anel_alvo.visible and _carros.has("jogador") \
				and _carros["jogador"].position.distance_to(_carros[alvo].position) < DISPUTA_M
		_traco.visible = disputa
		if disputa:
			var a: Vector3 = _carros["jogador"].position
			var b: Vector3 = _carros[alvo].position
			_traco.position = (a + b) * 0.5 + Vector3(0, 0.08, 0)
			_traco.scale = Vector3(a.distance_to(b), 1, 1)
			_traco.rotation.y = atan2(-(b.z - a.z), b.x - a.x)
	if visao_geral:
		_enquadrar_geral()
		_camera.size = _tamanho_geral
		_alvo_camera = _centro_pista
		_mudar_modo("normal", true)
		efeito_velocidade = 0.0
		(material as ShaderMaterial).set_shader_parameter("intensidade", 0.0)
		_camera_imediata()
		return
	var seguido: String = foco if _carros.has(foco) else ("jogador" if _carros.has("jogador") else (ordem[0] if not ordem.is_empty() else ""))
	if seguido == "":
		return
	var disputa_seguida := disputa and foco == "jogador"
	_mudar_modo(_decidir_modo(seguido, float(s[seguido]), disputa_seguida), delta <= 0.0)
	_animar_modo(delta)
	# O isométrico só está certo para quem aponta como o carro seguido (a câmera
	# fica atrás dele); numa reta, os carros próximos também. Os outros seguem
	# com o sprite de cima.
	var rumo_seg := _pista.rumo_em(float(s[seguido]))
	for id in _carros:
		if _carros[id] is CarroDesenho:
			var alinhado := smoothstep(0.82, 0.96, cos(angle_difference(_pista.rumo_em(float(s[id])), rumo_seg)))
			_carros[id].mistura(_mistura_sprite() * alinhado)
	var tamanho_alvo := TAMANHO_DISPUTA if modo == "foco" else TAMANHO_CAMERA
	_tamanho_base = tamanho_alvo if delta <= 0.0 or Preferencias.reduzir_animacoes \
			else lerpf(_tamanho_base, tamanho_alvo, clampf(delta * 1.5, 0.0, 1.0))
	_camera.size = _tamanho_base / _zoom
	_rumo_seguido = _pista.rumo_em(float(s[seguido]))
	var novo: Vector3 = _carros[seguido].position
	# No modo velocidade, a câmera mira um pouco à frente: mais pista livre adiante.
	novo += Vector3(cos(_rumo_seguido), 0.0, -sin(_rumo_seguido)) * _camera.size * 0.18 * _b
	# Inclinada, a câmera gira com o carro: atraso no seguimento vira deslocamento
	# grande na tela. Aí ela acompanha sem atraso.
	_alvo_camera = novo if delta <= 0.0 or Preferencias.reduzir_animacoes or _b > 0.0 \
			or _alvo_camera.distance_to(novo) > 40.0 else _alvo_camera.lerp(novo, clampf(delta * 5.0, 0.0, 1.0))
	efeito_velocidade = _b * clampf((float(_v.get(seguido, 0.0)) - V_MIN) / (V_FORTE - V_MIN), 0.3, 1.0)
	(material as ShaderMaterial).set_shader_parameter("intensidade",
			0.0 if Preferencias.reduzir_animacoes else efeito_velocidade)
	_camera_imediata()


func _camera_imediata() -> void:
	# Normal: de cima, girada 45° (o alto da tela para (-1, 0, -1)), a mesma
	# projeção do minimapa. Velocidade: 30° acima do chão, atrás do carro, na
	# direção em que o sprite isométrico foi desenhado. _b passa de uma à outra.
	# Câmera ortográfica longe (a escala não muda): nada fica atrás dela.
	var elevacao := lerpf(PI / 2.0 - 0.0005, deg_to_rad(30.0), _b)
	var guinada := lerp_angle(-PI / 4.0, _rumo_seguido + PI / 4.0, _b)
	var h := Vector3(cos(guinada), 0.0, -sin(guinada))
	var longe := 1400.0 * maxf(1.0, _camera.size / 960.0)
	var tremor := Vector3.ZERO
	if efeito_velocidade > 0.85 and not Preferencias.reduzir_animacoes:
		tremor = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _camera.size * 0.0015
	var alvo_c := _alvo_camera + tremor
	_camera.look_at_from_position(alvo_c + (h * cos(elevacao) + Vector3.UP * sin(elevacao)) * longe, alvo_c, -h)


# --- Modos de câmera (decisão 31) ---------------------------------------------

## "normal" (de cima), "foco" (disputa, mais perto) ou "velocidade" (inclinada,
## atrás do carro, sprite isométrico e efeito nas bordas).
var modo := "normal"
## Intensidade do efeito de tela (0..1), lida pela tela da corrida.
var efeito_velocidade := 0.0
var _b := 0.0  # 0 = de cima; 1 = velocidade
var _zoom := 1.0
var _tamanho_base := TAMANHO_CAMERA
var _rumo_seguido := 0.0
var _t_modo := 0.0
var _espera := 0.0
var _b_saida := 0.0
var _zoom_saida := 1.0
var _v := {}  # id -> velocidade suavizada (m/s)
## Apresentação, não balanceamento: duração da entrada e da saída, tempo mínimo
## entre duas entradas, quanto de reta (em segundos de percurso) justifica o
## modo e velocidade a partir da qual ele faz sentido.
const ENTRADA_S := 0.45
const SAIDA_S := 0.5
const ESPERA_S := 4.0
const RETA_ENTRA_S := 3.0
const RETA_SAI_S := 1.2
const CHEGADA_S := 3.0
const V_MIN := 22.0
const V_FORTE := 60.0


func _decidir_modo(id: String, s: float, disputa: bool) -> String:
	var calmo := "foco" if disputa else "normal"
	if Preferencias.reduzir_animacoes:
		return calmo
	var v: float = maxf(float(_v.get(id, 0.0)), 1.0)
	var i := _pista.indice_em(s)
	var t: Dictionary = _pista.trechos[i]
	var reta := float(t.get("raio_m", 0.0)) <= 0.0
	var resta := _pista.inicios[i] + float(t["comprimento_m"]) - fposmod(s, _pista.comprimento)
	var fim := _fonte.fim() if _fonte != null else 0.0
	var chegada := fim > 0.0 and s < fim and (fim - s) / v < CHEGADA_S
	if modo == "velocidade":
		if chegada or (reta and resta / v >= RETA_SAI_S):
			return "velocidade"
		return calmo
	if _espera <= 0.0 and v >= V_MIN and (chegada or (reta and resta / v >= RETA_ENTRA_S)):
		return "velocidade"
	return calmo


func _mudar_modo(novo: String, imediato: bool) -> void:
	if novo == modo:
		return
	if modo == "velocidade":
		_b_saida = _b
		_zoom_saida = _zoom
		_espera = ESPERA_S
	modo = novo
	_t_modo = 0.0
	if imediato:
		_b = 1.0 if novo == "velocidade" else 0.0
		_zoom = 1.32 if novo == "velocidade" else 1.0


## Entrada: aproxima com um pequeno passo além (1,00 → 1,38 → 1,32) enquanto
## inclina; saída: volta suave, sem passo além.
func _animar_modo(delta: float) -> void:
	_t_modo += delta
	_espera = maxf(_espera - delta, 0.0)
	if modo == "velocidade":
		var u := clampf(_t_modo / ENTRADA_S, 0.0, 1.0)
		_b = maxf(_b, smoothstep(0.1, 0.9, u))
		_zoom = lerpf(1.0, 1.38, smoothstep(0.0, 1.0, u / 0.7)) if u < 0.7 \
				else lerpf(1.38, 1.32, smoothstep(0.0, 1.0, (u - 0.7) / 0.3))
	else:
		var u := clampf(_t_modo / SAIDA_S, 0.0, 1.0)
		_b = lerpf(_b_saida, 0.0, smoothstep(0.0, 1.0, u))
		_zoom = lerpf(_zoom_saida, 1.0, smoothstep(0.0, 1.0, u))
		if u >= 1.0:
			_b_saida = 0.0
			_zoom_saida = 1.0


## A troca de sprite acontece com a câmera já perto e quase inclinada.
func _mistura_sprite() -> float:
	return smoothstep(0.35, 0.75, _b)


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
	_proj = proj
	_enquadrar_geral()
	var c_tela := proj.get_center()
	# Inverso de Iso.para_tela: x + y = cx, x - y = cy.
	var meio := Vector2((c_tela.x + c_tela.y) * 0.5, (c_tela.x - c_tela.y) * 0.5)
	_centro_pista = Vector3(meio.x, 0.0, -meio.y)
	var tema: Dictionary = TEMAS.get(_pista.id, TEMA_PADRAO)
	_ambiente.background_color = tema["ceu"]
	_ambiente.ambient_light_color = tema["ambiente"]
	_ambiente.fog_enabled = tema["neblina"] > 0.0
	_ambiente.fog_density = tema["neblina"]
	_ambiente.fog_light_color = tema["ceu"]
	_luz.light_color = tema["luz"]
	_luz.light_energy = tema["energia"]
	_luz.rotation = tema["sol"]
	_cores_muro = tema["muro"]
	var montado: Dictionary = KITS.get(_pista.id, {})
	var efeito := material as ShaderMaterial
	if not montado.is_empty() and MontadorPista.disponivel():
		# Cenário pelo kit de arte; os anéis, a linha de largada e os muros seguem daqui.
		MontadorPista.new().montar(_cena, _pista, montado, LARGURA_PISTA_M)
		_ambiente.background_color = montado.get("fundo", tema["ceu"])
		efeito.set_shader_parameter("vinheta", float(montado.get("vinheta", 0.0)))
		_marcadores()
		return
	efeito.set_shader_parameter("vinheta", 0.0)
	var grama := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = caixa.size + Vector2(8000, 8000)
	grama.mesh = plano
	grama.material_override = CarroBloco._material(tema["chao"])
	var centro := caixa.get_center()
	grama.position = Vector3(centro.x, -0.06, -centro.y)
	_cena.add_child(grama)
	_cena.add_child(_faixa(pts, LARGURA_PISTA_M + 6.0, -0.04, tema["chao"].darkened(0.25)))  # área de escape
	_cena.add_child(_faixa(pts, LARGURA_PISTA_M, 0.0, tema["asfalto"]))
	_cena.add_child(_zebras())
	for lado in [1.0, -1.0]:
		_cena.add_child(_muro(pts, lado * (LARGURA_PISTA_M * 0.5 + 3.4)))
	_marcadores()
	_arquibancada()
	_portico()
	_bordas()
	_placas_curva()
	_decorar(pts, tema["props"])
	_fundo(caixa, tema)


## Anéis do jogador e do alvo, traço de disputa e linha de largada.
func _marcadores() -> void:
	_anel_alvo = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 2.6
	tor.outer_radius = 3.1
	_anel_alvo.mesh = tor
	var mat_alvo := CarroBloco._material(Color(1.0, 0.3, 0.25))
	mat_alvo.emission_enabled = true
	mat_alvo.emission = Color(1.0, 0.2, 0.15) * 0.7
	_anel_alvo.material_override = mat_alvo
	_anel_alvo.visible = false
	_cena.add_child(_anel_alvo)
	_anel_jogador = MeshInstance3D.new()
	var tor_j := TorusMesh.new()
	tor_j.inner_radius = 2.5
	tor_j.outer_radius = 2.9
	_anel_jogador.mesh = tor_j
	var mat_j := CarroBloco._material(Color(1.0, 0.8, 0.15))
	mat_j.emission_enabled = true
	mat_j.emission = Color(1.0, 0.75, 0.1) * 0.6
	_anel_jogador.material_override = mat_j
	_anel_jogador.visible = false
	_cena.add_child(_anel_jogador)
	_traco = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.04, 0.35)
	_traco.mesh = bm
	var mat_t := CarroBloco._material(Color(1.0, 0.55, 0.2))
	mat_t.emission_enabled = true
	mat_t.emission = Color(1.0, 0.5, 0.15) * 0.7
	_traco.material_override = mat_t
	_traco.visible = false
	_cena.add_child(_traco)
	var largada := MeshInstance3D.new()
	var caixa_l := BoxMesh.new()
	caixa_l.size = Vector3(1.0, 0.02, LARGURA_PISTA_M)
	largada.mesh = caixa_l
	largada.material_override = CarroBloco._material(Color.WHITE)
	var p0 := _pista.posicao_em(0.0)
	largada.position = Vector3(p0.x, 0.01, -p0.y)
	largada.rotation.y = _pista.rumo_em(0.0)
	_cena.add_child(largada)


## Pórtico de largada e chegada sobre a pista, com faixa quadriculada.
func _portico() -> void:
	var p0 := _pista.posicao_em(0.0)
	var rumo := _pista.rumo_em(0.0)
	var lado := Vector2.from_angle(rumo + PI / 2.0)

	for k in [-1.0, 1.0]:
		var q: Vector2 = p0 + lado * k * (LARGURA_PISTA_M * 0.5 + 1.6)
		var poste := _bloco(Vector3(0.6, 7.5, 0.6), Color(0.3, 0.31, 0.34))
		poste.position = Vector3(q.x, 3.75, -q.y)
		_cena.add_child(poste)
	var quadros := 12
	for k in quadros:
		var t := (float(k) + 0.5) / quadros * 2.0 - 1.0
		var q := p0 + lado * t * (LARGURA_PISTA_M * 0.5 + 1.6)
		var quadro := _bloco(Vector3(0.4, 1.4, (LARGURA_PISTA_M + 3.2) / quadros),
				Color.WHITE if k % 2 == 0 else Color(0.08, 0.08, 0.09))
		quadro.position = Vector3(q.x, 7.0, -q.y)
		quadro.rotation.y = rumo
		_cena.add_child(quadro)


## Bordas: brita e pneus empilhados por fora das curvas; placas nas retas.
func _bordas() -> void:
	var brita := SurfaceTool.new()
	brita.begin(Mesh.PRIMITIVE_TRIANGLES)
	brita.set_normal(Vector3.UP)
	var pneus := []
	var placas := 0
	var s := 0.0
	var passo := 4.0
	while s < _pista.comprimento:
		var t := _pista.trecho_em(s)
		var raio := float(t.get("raio_m", 0.0))
		var rumo := _pista.rumo_em(s)
		var p := _pista.posicao_em(s)
		if raio > 0.0:
			# Por fora da curva: o lado oposto ao sentido dela.
			var fora := -1.0 if t.get("sentido", "esquerda") == "esquerda" else 1.0
			var n := Vector2.from_angle(rumo + PI / 2.0) * fora
			var n2 := Vector2.from_angle(_pista.rumo_em(s + passo) + PI / 2.0) * fora
			var p2 := _pista.posicao_em(s + passo)
			var q := [p + n * (LARGURA_PISTA_M * 0.5 + 1.2), p + n * (LARGURA_PISTA_M * 0.5 + 3.3),
					p2 + n2 * (LARGURA_PISTA_M * 0.5 + 1.2), p2 + n2 * (LARGURA_PISTA_M * 0.5 + 3.3)]
			for idx in [0, 2, 1, 1, 2, 3]:
				brita.add_vertex(Vector3(q[idx].x, 0.015, -q[idx].y))
			pneus.append(p + n * (LARGURA_PISTA_M * 0.5 + 2.8))
		elif placas < 24 and fposmod(s, 140.0) < passo:
			var lado := 1.0 if int(s / 140.0) % 2 == 0 else -1.0
			var q := p + Vector2.from_angle(rumo + PI / 2.0) * lado * (LARGURA_PISTA_M * 0.5 + 5.5)
			var cores := [Color(0.85, 0.15, 0.15), Color(0.15, 0.4, 0.85), Color(0.95, 0.75, 0.1), Color(0.15, 0.6, 0.35)]
			var placa := _bloco(Vector3(0.3, 2.2, 8.0), cores[placas % cores.size()])
			placa.position = Vector3(q.x, 1.6, -q.y)
			placa.rotation.y = rumo + PI / 2.0
			_cena.add_child(placa)
			var faixa := _bloco(Vector3(0.32, 0.4, 8.0), Color.WHITE)
			faixa.position = Vector3(q.x, 1.6, -q.y)
			faixa.rotation.y = rumo + PI / 2.0
			_cena.add_child(faixa)
			placas += 1
		s += passo
	var mb := MeshInstance3D.new()
	mb.mesh = brita.commit()
	var mat_b := CarroBloco._material(Color(0.72, 0.66, 0.52))
	mat_b.cull_mode = BaseMaterial3D.CULL_DISABLED
	mb.material_override = mat_b
	_cena.add_child(mb)
	# Pneus em MultiMesh: muitos objetos iguais, um só desenho.
	if not pneus.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cil := CylinderMesh.new()
		cil.top_radius = 0.45
		cil.bottom_radius = 0.45
		cil.height = 0.9
		cil.radial_segments = 8
		mm.mesh = cil
		mm.instance_count = pneus.size()
		for i in pneus.size():
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(pneus[i].x, 0.45, -pneus[i].y)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = CarroBloco._material(Color(0.1, 0.1, 0.11))
		_cena.add_child(mmi)


## Arquibancada ao lado da largada: referência para saber onde a volta começa.
func _arquibancada() -> void:
	var cores := [Color(0.75, 0.2, 0.2), Color(0.2, 0.4, 0.75), Color(0.85, 0.65, 0.15)]
	for k in 3:
		var s0 := -45.0 + k * 34.0
		var p0 := _pista.posicao_em(s0)
		var rumo := _pista.rumo_em(s0)
		var lado := Vector2.from_angle(rumo + PI / 2.0)
		var base := p0 + lado * (LARGURA_PISTA_M * 0.5 + 8.0)
		for degrau in 4:
			var b := _bloco(Vector3(30.0, 1.2, 3.0), cores[k] if degrau % 2 == 0 else Color(0.85, 0.85, 0.87))
			var q := base + lado * (degrau * 3.0)
			b.position = Vector3(q.x, 0.6 + degrau * 1.2, -q.y)
			b.rotation.y = rumo
			_cena.add_child(b)
		var cobertura := _bloco(Vector3(31.0, 0.3, 13.0), Color(0.88, 0.88, 0.9))
		var qc := base + lado * 4.5
		cobertura.position = Vector3(qc.x, 7.6, -qc.y)
		cobertura.rotation.y = rumo
		_cena.add_child(cobertura)
	# Prédio dos boxes do outro lado, com portas escuras.
	var pb := _pista.posicao_em(0.0)
	var rb := _pista.rumo_em(0.0)
	var outro := Vector2.from_angle(rb - PI / 2.0)
	var qb := pb + outro * (LARGURA_PISTA_M * 0.5 + 10.0)
	var predio := _bloco(Vector3(70.0, 5.0, 8.0), Color(0.82, 0.83, 0.86))
	predio.position = Vector3(qb.x, 2.5, -qb.y)
	predio.rotation.y = rb
	_cena.add_child(predio)
	for k in 8:
		var qp := pb + Vector2.from_angle(rb) * (-30.0 + k * 8.5) + outro * (LARGURA_PISTA_M * 0.5 + 5.95)
		var porta := _bloco(Vector3(6.0, 3.6, 0.1), Color(0.15, 0.16, 0.18))
		porta.position = Vector3(qp.x, 1.8, -qp.y)
		porta.rotation.y = rb
		_cena.add_child(porta)


## Placas de 100 e 50 m antes de cada curva, por fora: o piloto (e quem
## assiste) sabe que vem freada.
func _placas_curva() -> void:
	for i in _pista.trechos.size():
		var t: Dictionary = _pista.trechos[i]
		var anterior: Dictionary = _pista.trechos[i - 1]
		if float(t.get("raio_m", 0.0)) <= 0.0 or float(anterior.get("raio_m", 0.0)) > 0.0:
			continue
		var fora := -1.0 if t.get("sentido", "esquerda") == "esquerda" else 1.0
		for d in [100.0, 50.0]:
			var s: float = float(_pista.inicios[i]) - d
			var p := _pista.posicao_em(s) + Vector2.from_angle(_pista.rumo_em(s) + PI / 2.0) * fora * (LARGURA_PISTA_M * 0.5 + 2.4)
			var placa := _bloco(Vector3(0.15, 1.3, 1.0), Color.WHITE)
			placa.position = Vector3(p.x, 1.0, -p.y)
			placa.rotation.y = _pista.rumo_em(s)
			_cena.add_child(placa)
			for k in int(d / 50.0):
				var faixa := _bloco(Vector3(0.17, 0.16, 1.02), Color(0.1, 0.1, 0.12))
				faixa.position = Vector3(p.x, 0.65 + k * 0.4, -p.y)
				faixa.rotation.y = _pista.rumo_em(s)
				_cena.add_child(faixa)


## Cenário de fundo, fora do traçado: colinas (vale), água, guindastes e
## postes (porto), picos nevados (serra).
func _fundo(caixa: Rect2, tema: Dictionary) -> void:
	var centro := caixa.get_center()
	var raio := caixa.size.length() * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_pista.id + "fundo")
	match tema["fundo"]:
		"colinas":
			for k in 14:
				var ang := TAU * k / 14.0 + rng.randf() * 0.3
				var p := centro + Vector2.from_angle(ang) * (raio + rng.randf_range(80.0, 160.0))
				var colina := MeshInstance3D.new()
				var esf := SphereMesh.new()
				var r := rng.randf_range(50.0, 90.0)
				esf.radius = r
				esf.height = r * 0.7
				esf.radial_segments = 12
				esf.rings = 6
				colina.mesh = esf
				colina.material_override = CarroBloco._material(tema["chao"].lightened(rng.randf_range(0.04, 0.14)))
				colina.position = Vector3(p.x, -r * 0.12, -p.y)
				_cena.add_child(colina)
		"porto":
			# Água de um lado e guindastes na borda.
			var agua := MeshInstance3D.new()
			var plano := PlaneMesh.new()
			plano.size = Vector2(caixa.size.x + 600.0, 400.0)
			agua.mesh = plano
			var mat := CarroBloco._material(Color(0.12, 0.3, 0.45))
			mat.roughness = 0.2
			agua.material_override = mat
			agua.position = Vector3(centro.x, -0.05, -(caixa.position.y - 230.0))
			_cena.add_child(agua)
			for k in 5:
				var x := caixa.position.x + caixa.size.x * (k + 0.5) / 5.0
				var base := Vector3(x, 0.0, -(caixa.position.y - 40.0))
				var torre := _bloco(Vector3(3.0, 34.0, 3.0), Color(0.9, 0.55, 0.15))
				torre.position = base + Vector3(0, 17.0, 0)
				_cena.add_child(torre)
				var braco := _bloco(Vector3(3.0, 2.5, 36.0), Color(0.9, 0.55, 0.15))
				braco.position = base + Vector3(0, 33.0, 10.0)
				_cena.add_child(braco)
			var luz_poste := CarroBloco._material(Color(1.0, 0.85, 0.5))
			luz_poste.emission_enabled = true
			luz_poste.emission = Color(1.0, 0.8, 0.4)
			var s := 0.0
			while s < _pista.comprimento:
				var p := _pista.posicao_em(s) + Vector2.from_angle(_pista.rumo_em(s) + PI / 2.0) * (LARGURA_PISTA_M * 0.5 + 5.0)
				var poste := _bloco(Vector3(0.3, 7.0, 0.3), Color(0.25, 0.25, 0.28))
				poste.position = Vector3(p.x, 3.5, -p.y)
				_cena.add_child(poste)
				var lampada := _bloco(Vector3(0.9, 0.35, 0.9), Color.WHITE)
				lampada.material_override = luz_poste
				lampada.position = Vector3(p.x, 7.1, -p.y)
				_cena.add_child(lampada)
				s += 70.0
		"mesas":
			# Mesas de topo plano ao longe, cor de rocha avermelhada.
			for k in 8:
				var ang := TAU * k / 8.0 + rng.randf() * 0.5
				var p := centro + Vector2.from_angle(ang) * (raio + rng.randf_range(180.0, 320.0))
				var h := rng.randf_range(40.0, 90.0)
				var mesa := MeshInstance3D.new()
				var cil := CylinderMesh.new()
				cil.bottom_radius = rng.randf_range(90.0, 160.0)
				cil.top_radius = cil.bottom_radius * 0.75
				cil.height = h
				cil.radial_segments = 8
				cil.rings = 1
				mesa.mesh = cil
				mesa.material_override = CarroBloco._material(Color(0.7, 0.45, 0.32).lerp(Color(0.62, 0.58, 0.62), 0.35))
				mesa.position = Vector3(p.x, h * 0.5 - 2.0, -p.y)
				_cena.add_child(mesa)
		"montanhas":
			for k in 9:
				var ang := TAU * k / 9.0 + rng.randf() * 0.4
				var p := centro + Vector2.from_angle(ang) * (raio + rng.randf_range(160.0, 260.0))
				var h := rng.randf_range(120.0, 200.0)
				var monte := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = h * 0.9
				cone.height = h
				cone.radial_segments = 7
				cone.rings = 1
				monte.mesh = cone
				monte.material_override = CarroBloco._material(Color(0.48, 0.53, 0.6))  # azulado: distância
				monte.position = Vector3(p.x, h * 0.5 - 2.0, -p.y)
				_cena.add_child(monte)
				var neve := MeshInstance3D.new()
				var topo := CylinderMesh.new()
				topo.top_radius = 0.0
				topo.bottom_radius = h * 0.9 * 0.3
				topo.height = h * 0.3
				topo.radial_segments = 7
				topo.rings = 1
				neve.mesh = topo
				neve.material_override = CarroBloco._material(Color(0.95, 0.96, 1.0))
				neve.position = Vector3(p.x, h - 2.0 - h * 0.15 + 0.5, -p.y)
				_cena.add_child(neve)


## Objetos em volta da pista, longe do asfalto, sempre no mesmo lugar para a
## mesma pista (semente pelo id).
func _decorar(pts: PackedVector2Array, tipo: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_pista.id)
	var amostra := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		amostra.append(pts[i])
	var colocados := 0
	for tentativa in 800:
		if colocados >= maxi(110, int(_pista.comprimento / 25.0)):
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
		var n := _objeto(tipo, rng, dist)
		n.position.x = p.x
		n.position.z = -p.y
		n.rotation.y = rng.randf() * TAU
		_cena.add_child(n)


func _objeto(tipo: String, rng: RandomNumberGenerator, dist: float) -> Node3D:
	match tipo:
		"cidade":
			# Perto da pista só contêineres baixos: prédio alto ali tapa a corrida.
			if rng.randf() < 0.35 or dist < 40.0:
				var cont := _bloco(Vector3(6.0, 2.6, 2.4), [Color(0.8, 0.3, 0.2), Color(0.2, 0.45, 0.7), Color(0.85, 0.65, 0.2)][rng.randi() % 3])
				cont.position.y = 1.3
				return cont
			var h := rng.randf_range(6.0, 22.0)
			var predio := _bloco(Vector3(rng.randf_range(8.0, 14.0), h, rng.randf_range(8.0, 14.0)),
					Color(0.5, 0.52, 0.56).lerp(Color(0.7, 0.62, 0.52), rng.randf()))
			predio.position.y = h * 0.5
			return predio
		"deserto":
			# Placas de distância (marcas brancas) e pedras baixas: nada alto perto
			# das retas, que são o assunto da pista.
			if rng.randf() < 0.3 and dist < 40.0:
				var placa := _bloco(Vector3(0.3, 2.4, 1.6), Color(0.95, 0.95, 0.95))
				placa.position.y = 1.2
				return placa
			var rocha := _bloco(Vector3(rng.randf_range(1.5, 4.0), rng.randf_range(0.6, 1.8), rng.randf_range(1.5, 4.0)),
					Color(0.6, 0.48, 0.36).darkened(rng.randf_range(0.0, 0.2)))
			rocha.position.y = 0.4
			return rocha
		"serra":
			if rng.randf() < 0.4:
				var pedra := _bloco(Vector3.ONE * rng.randf_range(2.0, 5.0), Color(0.45, 0.43, 0.4))
				pedra.position.y = 0.8
				return pedra
			return _arvore(rng, Color(0.16, 0.32, 0.2), 1.3)
	if rng.randf() < 0.35:
		var arbusto := MeshInstance3D.new()
		var esf := SphereMesh.new()
		esf.radius = rng.randf_range(1.2, 2.2)
		esf.height = esf.radius * 1.3
		esf.radial_segments = 8
		esf.rings = 4
		arbusto.mesh = esf
		arbusto.material_override = CarroBloco._material(Color(0.22, 0.45, 0.2).darkened(rng.randf_range(0.0, 0.25)))
		arbusto.position.y = esf.height * 0.4
		return arbusto
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


## Visão geral: o traçado inteiro cabe na tela, qualquer que seja o tamanho
## dela agora (recalculado: a tela pode ter mudado desde a montagem).
func _enquadrar_geral() -> void:
	var aspecto := size.x / size.y if size.y > 1.0 else 1.2
	_tamanho_geral = maxf(_proj.size.y, _proj.size.x / aspecto) / sqrt(2.0) * 1.12 + 24.0


## Zebras vermelhas e brancas nas bordas das curvas.
func _zebras() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var passo := 3.0
	var s := 0.0
	var k := 0
	while s < _pista.comprimento:
		if float(_pista.trecho_em(s).get("raio_m", 0.0)) > 0.0:
			var cor := Color(0.85, 0.12, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.95)
			for lado in [1.0, -1.0]:
				var q := []
				for ss in [s, s + passo]:
					var p := _pista.posicao_em(ss)
					var n: Vector2 = Vector2.from_angle(_pista.rumo_em(ss) + PI / 2.0) * lado
					q.append(p + n * (LARGURA_PISTA_M * 0.5))
					q.append(p + n * (LARGURA_PISTA_M * 0.5 + 1.2))
				var v := q.map(func(p): return Vector3(p.x, 0.02, -p.y))
				for idx in [0, 2, 1, 1, 2, 3]:
					st.set_color(cor)
					st.add_vertex(v[idx])
		s += passo
		k += 1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


## Muro baixo ao longo da pista, a `deslocamento` m do eixo (lado pelo sinal).
func _muro(pts: PackedVector2Array, deslocamento: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_pts := pts.size()
	for i in n_pts - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var na := (pts[mini(i + 1, n_pts - 1)] - pts[maxi(i - 1, 0)]).normalized().orthogonal()
		var nb := (pts[mini(i + 2, n_pts - 1)] - pts[i]).normalized().orthogonal()
		var pa := a - na * deslocamento
		var pb := b - nb * deslocamento
		var cor: Color = _cores_muro[(i / 4) % 2]
		var v := [Vector3(pa.x, 0.0, -pa.y), Vector3(pb.x, 0.0, -pb.y), Vector3(pb.x, 0.9, -pb.y), Vector3(pa.x, 0.9, -pa.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(cor)
			st.add_vertex(v[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
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
