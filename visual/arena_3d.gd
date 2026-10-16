class_name Arena3D
extends SubViewportContainer
## Arena de destruição em 3D, de cima (decisão 50): só lê as amostras de
## Arena.correr (a simulação já resolveu tudo). Chão de terra batida num
## círculo, muro de pneus, carros com a mesma arte da corrida (sprite ou o
## carro em código). Dano por região: marcas escuras no ponto do carro, mais
## fortes a cada estágio (Arena.estagio); fumaça a partir do 4º estágio; o
## eliminado escurece e solta mais fumaça. Faíscas e um tranco de câmera nas
## batidas. A câmera enquadra os carros ainda vivos.
##
## Três modos de câmera (`modo`): "briga" (a sua briga, girando devagar),
## "geral" (a arena inteira, mais do alto) e "dinamica" (baixa, perto, com
## cortes: persegue quem acabou de bater ou o seu carro, alternando ângulos).
## Os seus carros (jogador e parceiro) ganham um anel no chão de tempos em
## tempos.

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
const CHAO_PASSO_M := 1.0  # fino o bastante para a quina das rampas e dos degraus
const CHAO_MARGEM_M := 22.0  # da maior largura do muro à borda do bloco (arquibancada, árvores)
## Direção da luz pré-calculada no chão (de onde vem a luz, normalizada).
const LUZ_CHAO := Vector3(0.55, 0.62, 0.56)
const FUMACA_ESTAGIO := 3  # estágio (0..4) a partir do qual sai fumaça
## Vista geral: mais do alto e a arena inteira com folga.
const ELEVACAO_GERAL_GRAUS := 40.0  # ângulo de maquete: mostra as laterais e o que é alto
const ORBITA_GERAL_S := 90.0
## Dinâmica: planos curtos, baixos e perto, com corte seco.
const PLANO_S := 6.0  # duração de um plano sem batida
const CORTE_MIN_S := 2.5  # um plano dura pelo menos isso antes de cortar para uma batida
const DANO_CORTE := 0.06  # batida que chama a câmera
const ATRAS_M := 15.0
const ALTURA_M := 5.5
const LADO_M := 14.0
const CAMERA_DINAMICA_SUAVE := 3.5  # 1/s
## Anel nos seus carros: a cada ANEL_PERIODO_S, por ANEL_S.
const ANEL_PERIODO_S := 6.0
const ANEL_S := 1.6
const SEUS := ["jogador", "parceiro"]
## Tombo (só visual): batida forte de lado levanta o carro sobre duas rodas e
## ele cai de volta; de frente ou de trás, o nariz ou a traseira saltam. A
## gravidade traz de volta e o chão quica pouco. Velocidade angular = dano ×
## ganho, com teto. Capotagem (pedido do usuário): a batida muito forte de lado
## (arena.json → capota_dano, a mesma regra da simulação) passa do ponto de tombar, o carro gira no ar e cai de teto
## para baixo, e fica assim (como no Destruction Derby; decisão do usuário).
const TOMBO_DANO := 0.06  # dano mínimo da batida de lado que levanta o carro
const TOMBO_DANO_PONTA := 0.12  # de frente/trás (são muitas: só as fortes)
const TOMBO_GANHO_LADO := 20.0
const TOMBO_GANHO_PONTA := 9.0
const TOMBO_MAX_LADO := 4.0  # rad/s: ~50° no pico (só a batida de capotar vira o carro)
const TOMBO_MAX_PONTA := 1.6  # ~8°: o nariz não sobe por cima do outro carro
const TOMBO_GRAVIDADE := 9.0  # rad/s²
const TOMBO_QUIQUE := 0.25
const TOMBO_VIRA := 1.25  # rad: o máximo que tomba de lado sem capotar (aí volta)
const CAPOTA_V := 9.0  # rad/s da volta no ar (~0,7 s)
const CAPOTA_SALTO_M := 1.1  # altura do arco da volta
const ALTURA_CARRO_M := 1.35  # de teto para baixo, o carro apoia no teto
const MEIA_LARGURA_M := 0.85
const MEIO_COMPRIMENTO_M := 2.1

## "briga", "geral" ou "dinamica".
var modo := "briga":
	set(v):
		modo = v
		_corte = true

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
## Nível de blindagem à vista por carro (decisão 80): id -> 1..3.
var blindagens := {}
## Proteções soltas caindo: [{no, v (m/s), giro (rad/s), chao (m)}].
var _soltas: Array = []
## Região da batida -> proteção do modelo (o "left" do pacote fica no -X do
## arquivo, que é a direita do carro no jogo).
const PROTECAO_DA_REGIAO := {"frente_e": "front", "frente_d": "front", "tras_e": "rear", "tras_d": "rear",
		"lado_e": "right", "lado_d": "left"}
const SOLTA_DANO := 0.05  # batida que arranca a proteção da região
var _orbita := 0.0  # ângulo da câmera em volta do centro (rad)
var _carros := {}  # id -> Node3D
var _malhas := {}  # id -> [{mi, rel, surfs: [{arr, prim, mat}]}]: malhas originais da carroceria
var _estagio_visto := {}  # id -> estágio de dano por região já aplicado na malha
var _objetos: ObjetosArena
## Arquibancadas (pacote do usuário, visual/arquibancada): [{no, centro (2D), modulos}].
var _arquibancadas: Array = []
var _corpos := {}  # id -> AnimatableBody3D (física de tela)
var _incendio := {}  # id -> Incendio3D (fumaça, fogo e explosão do pacote de dano)
var _pilotos := {}  # id do carro -> Piloto3D (fugindo do carro em chamas)
var _piloto_fora := {}  # id -> s ainda correndo para fora do muro antes de sumir
var _piloto_fuga := {}  # data/arena.json → piloto_fuga
var _capota_dano := 0.2  # data/arena.json → capota_dano
## Destroços soltos ficam no chão; acima disso, os mais antigos somem (celular).
const SOLTAS_MAX := 80
## Camadas de colisão da física de tela (pacote de dano, adaptadas): 1 chão,
## 2 objetos e piloto, 4 carros, 8 destroços.
const CAMADA_CHAO := 1
const CAMADA_OBJETO := 2
const CAMADA_CARRO := 4
## Depois de chegar ao muro, o piloto corre mais isso e some (s).
const PILOTO_SAI_S := 1.5
var _eventos_vistos := 0
var _estagios := 5
var _raio := 45.0
var _forma: ArenaForma  # muro, obstáculos e relevo (a mesma forma da simulação)
var _centro := Vector3.ZERO
var _tamanho := 60.0
var _tremor := 0.0
var _aneis := {}  # id -> MeshInstance3D (só os seus carros)
var _marcadores := {}  # id -> MeshInstance3D (visão geral: o carro de longe)
var _tombo := {}  # id -> {rolagem, v_rolagem, arfagem, v_arfagem} (rad, rad/s)
var _foco := "jogador"  # carro da câmera dinâmica
var _plano := 0  # 0 perseguição, 1 lateral, 2 frente baixa
var _plano_desde := 0.0
var _corte := true  # próximo quadro da câmera dinâmica sem suavizar
var _pos_cam := Vector3.ZERO
var _olhar := Vector3.ZERO


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
	env.background_color = Color(0.8, 0.77, 0.74)  # fundo claro de estúdio: a arena é uma maquete
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.58)
	CarroBloco.reflexo(env)  # o reflexo do verniz na pintura
	amb.environment = env
	_mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	# Luz baixa, de lado: as encostas do chão irregular ganham luz e sombra.
	luz.rotation = Vector3(-0.55, 0.75, 0)
	luz.shadow_enabled = not Preferencias.efeitos_leves
	luz.light_color = Color(1.0, 0.9, 0.78)
	luz.light_energy = 1.15
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
	_aneis = {}
	_marcadores = {}
	_tombo = {}
	_soltas = []
	_malhas = {}
	_estagio_visto = {}
	_incendio = {}
	_corpos = {}
	_pilotos = {}
	_piloto_fora = {}
	_piloto_fuga = params.get("piloto_fuga", {})
	_capota_dano = float(params.get("capota_dano", 0.2))
	_resultado = resultado
	_amostras = resultado.get("amostras", [])
	_estagios = int(params.get("estagios", 5))
	_lotacao = LOTACAO.get(String(params.get("forma", {}).get("licenca", "")), 1)
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
		if CarroBloco.tem_modelo(String(base.get("id", ""))) \
				or not c.configurar(String(base.get("id", "")), pinturas.get(id, Color(0, 0, 0, 0))):
			c.free()
			c = CarroBloco.new().configurar_modelo(base, cor, faixas_pintura.get(id, {}))
		_cena.add_child(c)
		_carros[id] = c
		_corpos[id] = _corpo_fisico(c)
		_malhas[id] = _malhas_carroceria(c)
		if int(blindagens.get(id, 0)) > 0 and c is CarroBloco:
			(c as CarroBloco).blindar(String(base.get("id", "")), int(blindagens[id]))
		if id in SEUS:
			_aneis[id] = _anel()
		_marcadores[id] = _marcador(Aba.COR_DESTAQUE if id in SEUS else cor)
	_foco = "jogador" if _carros.has("jogador") else String(_carros.keys()[0])
	_plano = 0
	_plano_desde = 0.0
	_corte = true
	atualizar(0.0)
	_tamanho = _alvo_tamanho()
	_camera.size = _tamanho
	_mirar()


## Até o fim da cena: depois do resultado, o fogo, a fuga e a explosão que
## faltavam (só tela).
func duracao() -> float:
	return float(_resultado.get("duracao_cena", _resultado.get("duracao", 0.0)))


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
		var antes := c.position
		c.position = Vector3(p.x, _forma.altura(p), -p.y)
		if delta > 0.0:
			_corpos[id].set_meta("vel", (c.position - antes) / delta)
		var rumo := lerp_angle(float(sa["rumo"]), float(sb["rumo"]), u)
		c.rotation.y = rumo
		# Chão irregular: o carro inclina com ele (frente sobe na subida; o lado
		# mais alto do terreno levanta o lado do carro).
		var g := _forma.gradiente(p)
		var f := Vector2.from_angle(rumo)
		c.rotation.z = atan(g.dot(f))
		c.rotation.x = atan(g.dot(Vector2(-f.y, f.x)))
		if _tombo.has(id):
			var tb: Dictionary = _tombo[id]
			c.rotation.x += tb["rolagem"]
			c.rotation.z += tb["arfagem"]
			# Gira sobre as rodas de um lado (ou um eixo): o centro sobe; de
			# teto para baixo, apoia no teto; capotando, voa num arco.
			var rl := float(tb["rolagem"])
			c.position.y += absf(sin(rl)) * MEIA_LARGURA_M + (1.0 - cos(rl)) * 0.5 * ALTURA_CARRO_M \
					+ absf(sin(tb["arfagem"])) * MEIO_COMPRIMENTO_M + float(tb.get("salto", 0.0))
		_mostrar_dano(id, sb["dano"], bool(sb["eliminado"]))
	_mostrar_aneis(b)
	_mostrar_marcadores(b)
	_canhoes(b, delta)
	_eventos(delta)
	_mover_pilotos(a, b, u, delta)
	_assentar(delta)
	_cair_soltas(delta)
	if delta > 0.0:
		_tamanho = lerpf(_tamanho, _alvo_tamanho(), 1.0 - exp(-delta * CAMERA_SUAVE))
		_camera.size = _tamanho
		_tremor = maxf(_tremor - delta, 0.0)
		if not Preferencias.reduzir_animacoes:
			_orbita = fmod(_orbita + delta * TAU / (ORBITA_GERAL_S if modo == "geral" else ORBITA_S), TAU)
	if modo == "dinamica":
		_dirigir(b, delta)
		return
	_mirar()


## Enquadramento: os vivos (todos, se já acabou), com folga, dentro da arena.
## Na vista geral, a arena inteira.
func _alvo_tamanho() -> float:
	if modo == "geral":
		_centro = _centro.lerp(Vector3.ZERO, 0.08)
		var asp_g := float(size.y) / maxf(float(size.x), 1.0) if size.x > 0 else 1.6
		# Do alto e inclinada, a largura da tela é que limita o círculo.
		return (_raio * 2.0 + FOLGA_M) * maxf(asp_g, 1.0) * 1.25
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
	var elev := deg_to_rad(ELEVACAO_GERAL_GRAUS if modo == "geral" else ELEVACAO_GRAUS)
	var h := Vector3(sin(_orbita), 0.0, cos(_orbita))
	if modo == "geral":
		c += h * _raio * 0.12  # mira aquém do centro: o bloco sobe e ocupa a tela (o painel é estreito)
	_camera.look_at_from_position(c + (h * cos(elev) + Vector3.UP * sin(elev)) * d, c, Vector3.UP)


# --- Câmera dinâmica ------------------------------------------------------------

## Escolhe o carro e o ângulo: corta para quem bateu forte (depois de
## CORTE_MIN_S no plano), troca de plano a cada PLANO_S e larga quem caiu.
func _dirigir(amostra: Dictionary, delta: float) -> void:
	var vivo := func(id): return _carros.has(id) and not bool(amostra[id]["eliminado"])
	var desde := tempo - _plano_desde
	if not vivo.call(_foco) and desde > 1.2:
		_novo_plano(_proximo_foco(amostra))
	elif desde >= PLANO_S:
		_novo_plano(_proximo_foco(amostra))
	var c: Node3D = _carros[_foco]
	var f := Vector3(cos(c.rotation.y), 0.0, -sin(c.rotation.y))  # a frente (rumo no plano)
	var lado := Vector3(-f.z, 0.0, f.x)
	var alvo_pos: Vector3
	var alvo_olhar: Vector3
	match _plano:
		0:  # atrás, olhando para onde vai
			alvo_pos = c.position - f * ATRAS_M + Vector3.UP * ALTURA_M
			alvo_olhar = c.position + f * 6.0 + Vector3.UP * 0.8
		1:  # de lado, baixo
			alvo_pos = c.position + lado * LADO_M + Vector3.UP * (ALTURA_M * 0.6)
			alvo_olhar = c.position + Vector3.UP * 0.8
		_:  # à frente, baixa: o carro vem para a câmera
			alvo_pos = c.position + f * ATRAS_M * 1.1 + Vector3.UP * (ALTURA_M * 0.45)
			alvo_olhar = c.position + Vector3.UP * 1.0
	# Dentro da arena (o muro não fica entre a câmera e o carro).
	var plano := Vector2(alvo_pos.x, -alvo_pos.z)
	if plano.length() > _raio - 2.0:
		plano = plano.normalized() * (_raio - 2.0)
		alvo_pos = Vector3(plano.x, alvo_pos.y, -plano.y)
	if _corte or delta <= 0.0:
		_pos_cam = alvo_pos
		_olhar = alvo_olhar
		_corte = false
	else:
		var k := 1.0 - exp(-delta * CAMERA_DINAMICA_SUAVE)
		_pos_cam = _pos_cam.lerp(alvo_pos, k)
		_olhar = _olhar.lerp(alvo_olhar, minf(k * 1.6, 1.0))
	var tremor := Vector3.ZERO
	if _tremor > 0.0 and not Preferencias.reduzir_animacoes:
		tremor = Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)) * 0.35 * _tremor
	_camera.look_at_from_position(_pos_cam + tremor, _olhar, Vector3.UP)


func _novo_plano(id: String) -> void:
	_foco = id
	_plano = (_plano + 1) % 3
	_plano_desde = tempo
	_corte = true


## Roda entre os seus carros vivos e o rival mais perto deles.
func _proximo_foco(amostra: Dictionary) -> String:
	var vivos: Array = _carros.keys().filter(func(id): return not bool(amostra[id]["eliminado"]))
	if vivos.is_empty():
		return _foco
	var ordem: Array = vivos.filter(func(id): return id in SEUS)
	var ref: Vector3 = _carros[ordem[0] if not ordem.is_empty() else _foco].position
	var rivais: Array = vivos.filter(func(id): return not id in SEUS)
	if not rivais.is_empty():
		rivais.sort_custom(func(a, b): return ref.distance_to(_carros[a].position) < ref.distance_to(_carros[b].position))
		ordem.append(rivais[0])
	return ordem[(ordem.find(_foco) + 1) % ordem.size()]


## Batida forte na dinâmica: corta para o carro atingido (depois de CORTE_MIN_S).
func _chamar_batida(e: Dictionary) -> void:
	if modo != "dinamica" or float(e["dano"]) < DANO_CORTE or tempo - _plano_desde < CORTE_MIN_S:
		return
	var quem := String(e["por"]) if _carros.has(String(e["por"])) else String(e["carro"])
	_foco = quem
	_plano = 1 if _plano != 1 else 2  # a batida pede um ângulo de lado ou de frente
	_plano_desde = tempo
	_corte = true


# --- Tombo -----------------------------------------------------------------------

## Batida forte: impulso de rolagem (de lado; o lado atingido sobe) ou de
## arfagem (frente/trás; a ponta atingida sobe).
func _tombar(e: Dictionary) -> void:
	var dano := float(e["dano"])
	if dano < TOMBO_DANO or Preferencias.reduzir_animacoes:
		return
	var id := String(e["carro"])
	var tb: Dictionary = _tombo.get(id, {"rolagem": 0.0, "v_rolagem": 0.0, "arfagem": 0.0, "v_arfagem": 0.0})
	var regiao := String(e.get("regiao", ""))
	if regiao.begins_with("lado"):
		var sinal := 1.0 if regiao.ends_with("_e") else -1.0
		if dano >= _capota_dano and not tb.get("capota", false):
			tb["v_rolagem"] = sinal * CAPOTA_V
		else:
			tb["v_rolagem"] = float(tb["v_rolagem"]) + sinal * minf(dano * TOMBO_GANHO_LADO, TOMBO_MAX_LADO)
	elif dano >= TOMBO_DANO_PONTA:
		var sinal_p := 1.0 if regiao.begins_with("frente") else -1.0
		tb["v_arfagem"] = float(tb["v_arfagem"]) + sinal_p * minf(dano * TOMBO_GANHO_PONTA, TOMBO_MAX_PONTA)
	_tombo[id] = tb


## A gravidade traz o carro de volta às quatro rodas, com um quique curto.
## A batida que capota (capota_dano) gira o carro no ar até o teto, e ele fica assim.
func _assentar(delta: float) -> void:
	if delta <= 0.0:
		return
	for id in _tombo.keys():
		var tb: Dictionary = _tombo[id]
		if tb.get("capota", false):
			var r := float(tb["rolagem"]) + float(tb["v_rolagem"]) * delta
			# Capotou, fica de teto para baixo (pedido do usuário, como no
			# Destruction Derby: a volta inteira de volta às rodas era artificial).
			var fim := PI
			if absf(r) >= fim:
				tb["capota"] = false
				tb["rolagem"] = signf(r) * PI
				tb["v_rolagem"] = 0.0
				tb["salto"] = 0.0
				tb["fixo"] = true  # de teto para baixo até o fim
			else:
				tb["rolagem"] = r
				tb["salto"] = sin(absf(r) / fim * PI) * CAPOTA_SALTO_M
			continue
		if tb.get("fixo", false):
			continue
		# Só capota a batida que capota na simulação (capota_dano); o resto
		# para no limite de tombar e volta.
		if absf(float(tb["rolagem"])) > TOMBO_VIRA:
			tb["rolagem"] = signf(float(tb["rolagem"])) * TOMBO_VIRA
			tb["v_rolagem"] = minf(float(tb["v_rolagem"]) * signf(float(tb["rolagem"])), 0.0) * signf(float(tb["rolagem"]))
		for eixo in [["rolagem", "v_rolagem"], ["arfagem", "v_arfagem"]]:
			var a := float(tb[eixo[0]])
			var v := float(tb[eixo[1]])
			if a == 0.0 and v == 0.0:
				continue
			var lado := signf(a) if a != 0.0 else signf(v)
			v -= lado * TOMBO_GRAVIDADE * delta
			var novo := a + v * delta
			if signf(novo) != lado:  # tocou o chão
				novo = 0.0
				v = -v * TOMBO_QUIQUE
				if absf(v) < 0.4:
					v = 0.0
			tb[eixo[0]] = novo
			tb[eixo[1]] = v
		if float(tb["rolagem"]) == 0.0 and float(tb["v_rolagem"]) == 0.0 \
				and float(tb["arfagem"]) == 0.0 and float(tb["v_arfagem"]) == 0.0:
			_tombo.erase(id)


func _eliminado(id: String) -> bool:
	return _i < _amostras.size() and bool(_amostras[mini(_i + 1, _amostras.size() - 1)].get(id, {}).get("eliminado", false))


# --- Anéis dos seus carros ---------------------------------------------------------

func _anel() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 2.7
	tor.outer_radius = 3.15
	m.mesh = tor
	var mat := CarroBloco._material(Aba.COR_DESTAQUE)
	mat.emission_enabled = true
	mat.emission = Aba.COR_DESTAQUE * 0.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	_cena.add_child(m)
	return m


## A cada ANEL_PERIODO_S o anel aparece por ANEL_S, crescendo e sumindo (com
## Reduzir animações, parado). Carro eliminado não tem anel.
func _mostrar_aneis(amostra: Dictionary) -> void:
	var u := fmod(tempo, ANEL_PERIODO_S) / ANEL_S
	for id in _aneis:
		var a: MeshInstance3D = _aneis[id]
		a.visible = u < 1.0 and not bool(amostra[id]["eliminado"])
		if not a.visible:
			continue
		a.position = _carros[id].position + Vector3(0, 0.12, 0)
		var mat := a.material_override as StandardMaterial3D
		if Preferencias.reduzir_animacoes:
			a.scale = Vector3.ONE
			mat.albedo_color.a = 0.85
		else:
			a.scale = Vector3.ONE * lerpf(0.85, 1.3, smoothstep(0.0, 1.0, u))
			mat.albedo_color.a = (1.0 - smoothstep(0.4, 1.0, u)) * 0.9


# --- Marcadores da visão geral ------------------------------------------------------

const MARCADOR_ALTURA_M := 4.0  # acima do carro, na escala 1
const MARCADOR_TAMANHO_REF := 75.0  # quadro (m) em que o marcador tem a escala 1


## Losango na cor do carro (os seus em âmbar) acima dele: de longe, o carro
## (4,5 m numa arena de 100 m) some; o marcador mostra onde está a briga.
func _marcador(cor: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var losango := PrismMesh.new()
	losango.size = Vector3(1.6, 2.2, 1.6)
	m.mesh = losango
	m.rotation.z = PI  # ponta para baixo
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	_cena.add_child(m)
	return m


## Só na visão geral; cresce com o quadro (fica do mesmo tamanho na tela) e
## some com o carro eliminado.
func _mostrar_marcadores(amostra: Dictionary) -> void:
	var esc := clampf(_tamanho / MARCADOR_TAMANHO_REF, 0.6, 4.0)
	var sobe := 0.0 if Preferencias.reduzir_animacoes else sin(tempo * 3.0) * 0.3
	for id in _marcadores:
		var m: MeshInstance3D = _marcadores[id]
		m.visible = modo == "geral" and not bool(amostra[id]["eliminado"])
		if m.visible:
			m.scale = Vector3.ONE * esc
			m.position = _carros[id].position + Vector3.UP * (MARCADOR_ALTURA_M + sobe) * esc


# --- Dano -----------------------------------------------------------------------

## Uma marca por região (Arena.REGIOES), no ponto do carro: frente/lado/trás e
## esquerda/direita. Frente em +X, esquerda em -Z (o +Y do plano da arena).
## Amassado de verdade: a malha da carroceria afunda na região atingida, na
## proporção do estágio de dano (as seis regiões da simulação), com um enrugado
## irregular e sombreamento facetado. Rodas ficam de fora.
## Região: centro no carro (+X frente, -Z esquerda, em frações de comprimento,
## altura em m e largura), direção do afundamento e raio (fração do comprimento).
const AMASSADOS := [
	{"c": Vector3(0.5, 0.6, -0.32), "dir": Vector3(-1.0, -0.3, 0.4), "raio": 0.42, "prof": 0.4},  # frente_e
	{"c": Vector3(0.5, 0.6, 0.32), "dir": Vector3(-1.0, -0.3, -0.4), "raio": 0.42, "prof": 0.4},  # frente_d
	{"c": Vector3(0.05, 0.65, -0.5), "dir": Vector3(0.0, -0.2, 1.0), "raio": 0.34, "prof": 0.28},  # lado_e
	{"c": Vector3(0.05, 0.65, 0.5), "dir": Vector3(0.0, -0.2, -1.0), "raio": 0.34, "prof": 0.28},  # lado_d
	{"c": Vector3(-0.5, 0.6, -0.32), "dir": Vector3(1.0, -0.3, 0.4), "raio": 0.4, "prof": 0.35},  # tras_e
	{"c": Vector3(-0.5, 0.6, 0.32), "dir": Vector3(1.0, -0.3, -0.4), "raio": 0.4, "prof": 0.35},  # tras_d
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
		fator.append(float(estagios[r]) / maxf(_estagios, 1) * (1.05 if eliminado else 1.0))
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
	var c0 = _carros[id]
	for r in dano.size():
		# Com a placa da região ainda no lugar, a lataria não amassa (pedido do
		# usuário): o amassado aparece quando ela cai.
		var coberta: bool = c0 is CarroBloco and (c0 as CarroBloco).protecao(
				String(PROTECAO_DA_REGIAO.get(Arena.REGIOES[r], ""))) != null
		est.append(Arena.estagio(dano[r], _estagios) + 1 if dano[r] > 0.0 and not coberta else 0)
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
	if fumando and not Preferencias.efeitos_leves:
		_fogo_de(id).fumacar(eliminado)


func _tingir(n: Node, tom: Color) -> void:
	for f in n.get_children():
		if f is SpriteBase3D and not f.top_level:
			f.modulate = Color(tom, f.modulate.a)
		elif f is GeometryInstance3D and f.material_override is ShaderMaterial:
			pass
		_tingir(f, tom)


## Batidas novas até o tempo atual: faíscas no carro atingido e um tranco.
func _eventos(_delta: float) -> void:
	var evs: Array = _resultado.get("eventos", [])
	while _eventos_vistos < evs.size() and float(evs[_eventos_vistos]["t"]) <= tempo:
		var e: Dictionary = evs[_eventos_vistos]
		_eventos_vistos += 1
		if not _carros.has(e["carro"]):
			continue
		match String(e["tipo"]):
			"fogo":
				_fogo_de(e["carro"]).fogo()
			"fuga":
				_fuga(e)
			"explosao":
				_explodir(e)
			"atropelo":
				_atropelar(e)
		if e["tipo"] != "impacto":
			continue
		_chamar_batida(e)
		Sons.impacto(self, float(e["dano"]))
		var pc: Vector3 = _carros[e["carro"]].position
		_reagir_publico(e, Vector2(pc.x, -pc.z))
		_tombar(e)
		_soltar(e)
		var forte := float(e["dano"]) > 0.08
		if forte:
			_tremor = minf(_tremor + float(e["dano"]) * 2.0, 0.6)
		if not e.get("explosao", false):
			_faiscas(_carros[e["carro"]].global_position + Vector3(0, 0.8, 0), forte)


# --- Fogo, fuga e explosão (pacote de dano) ----------------------------------------

func _fogo_de(id: String) -> Incendio3D:
	if not _incendio.has(id):
		var f := Incendio3D.new()
		var c: Node3D = _carros[id]
		var comp: float = (c as CarroBloco).dimensoes().x if c is CarroBloco else Arena.COMPRIMENTO_M
		f.motor = Vector3(comp * 0.3, 0.9, 0.0)  # frente em +X
		c.add_child(f)
		_incendio[id] = f
	return _incendio[id]


## A porta do lado do muro abre e o piloto sai correndo.
func _fuga(e: Dictionary) -> void:
	var c: Node3D = _carros[e["carro"]]
	var dim: Vector2 = (c as CarroBloco).dimensoes() if c is CarroBloco else Vector2(Arena.COMPRIMENTO_M, Arena.LARGURA_M)
	var lado := float(e.get("lado", 1.0))  # +1 esquerda (+Y da simulação = −Z do mundo)
	var porta := Node3D.new()
	c.add_child(porta)
	porta.position = Vector3(dim.x * 0.12, 0.98, -lado * dim.y * 0.5)
	var chapa := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(.68, .55, .045)
	chapa.mesh = caixa
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.74, .73, .66)
	chapa.material_override = m
	porta.add_child(chapa)
	chapa.position.x = -.34
	create_tween().tween_property(porta, "rotation:y", lado * .95, .35)
	Sons.tocar_ui(self, "porta_abre", -4.0)
	Sons.tocar_ui(self, "ofegante", -8.0)
	var p := Piloto3D.new()
	_cena.add_child(p)
	_pilotos[e["carro"]] = p
	p.global_position = c.global_position + Vector3(0, 0, -lado * (dim.y * 0.5 + 0.3))


func _explodir(e: Dictionary) -> void:
	var id := String(e["carro"])
	_fogo_de(id).explodir()
	_tremor = minf(_tremor + 0.5, 0.8)
	Sons.estrondo(self)
	Sons.tocar_ui(self, "impacto", 0.0, 0.8)
	_comemorar_todas()
	var c = _carros[id]
	if c is CarroBloco:
		(c as CarroBloco).carbonizar()
		for r: Node3D in (c as CarroBloco).soltar_rodas(_cena):
			_lancar(r, Vector3(randf_range(-4, 4), randf_range(2, 4), randf_range(-3, 3)), Vector3(4, 2, 1))
	# Quatro chapas da carroceria.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.18, .17, .14)
	for k in 4:
		var chapa := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(.55, .05, .35)
		chapa.mesh = caixa
		chapa.material_override = m
		_cena.add_child(chapa)
		chapa.global_position = (c as Node3D).global_position + Vector3(randf_range(-.5, 1.0), 1.0, randf_range(-.4, .4))
		_lancar(chapa, Vector3(randf_range(-3, 3), randf_range(3, 6), randf_range(-3, 3)), Vector3(3, 2, -2))


## Destroço solto: cai, quica e para no chão (mesmo caminho das proteções).
func _lancar(no: Node3D, v: Vector3, giro: Vector3) -> void:
	_soltas.append({"no": no, "v": v, "giro": giro})
	while _soltas.size() > SOLTAS_MAX:
		var velho: Dictionary = _soltas.pop_front()
		if is_instance_valid(velho["no"]):
			(velho["no"] as Node3D).queue_free()


## O carro que atropelou: velocidade dele nas amostras em volta do tempo.
func _atropelar(e: Dictionary) -> void:
	var p: Piloto3D = _pilotos.get(e["carro"])
	if p == null:
		return
	var por := String(e["por"])
	var a: Dictionary = _amostras[maxi(_i - 1, 0)]
	var b: Dictionary = _amostras[mini(_i + 1, _amostras.size() - 1)]
	var v2 := Vector2.ZERO
	if a.has(por) and b.has(por) and float(b["t"]) > float(a["t"]):
		v2 = ((b[por]["pos"] as Vector2) - (a[por]["pos"] as Vector2)) / (float(b["t"]) - float(a["t"]))
	if v2.length() < 0.5:
		v2 = Vector2.from_angle(float(b[por]["rumo"])) * float(e.get("v", 5.0))
	p.set_meta("caido_s", 0.0)
	p.atropelar(Vector3(v2.x, 0, -v2.y))


## Os pilotos seguem a simulação: correndo, no ponto dela; caído, o ragdoll;
## levantando, voltam ao ponto dela; fora, correm mais um pouco e somem.
func _mover_pilotos(a: Dictionary, b: Dictionary, u: float, delta: float) -> void:
	for id in _pilotos.keys():
		var p: Piloto3D = _pilotos[id]
		if not is_instance_valid(p):
			_pilotos.erase(id)
			continue
		if _piloto_fora.has(id):
			_piloto_fora[id] = float(_piloto_fora[id]) - delta
			p.avancar(float(_piloto_fuga.get("v_ms", 2.8)) * delta)
			if float(_piloto_fora[id]) <= 0.0:
				p.queue_free()
				_pilotos.erase(id)
				_piloto_fora.erase(id)
			continue
		if tempo >= float(_amostras[-1]["t"]):
			_piloto_sozinho(id, p, delta)
			continue
		var pa: Dictionary = a.get("pilotos", {}).get(id, {})
		var pb: Dictionary = b.get("pilotos", {}).get(id, pa)
		if pb.is_empty():
			continue
		if pa.is_empty():
			pa = pb
		var pos: Vector2 = (pa["pos"] as Vector2).lerp(pb["pos"], u)
		var onde := Vector3(pos.x, _forma.altura(pos), -pos.y)
		if p.estado == "caido":
			p.set_meta("caido_s", float(p.get_meta("caido_s", 0.0)) + delta)
		var est := String(pb["estado"])
		if est in ["correndo", "fora"] and p.estado == "caido":
			p.levantar(onde, 0.5)  # pulou o tempo: levanta já
		match est:
			"correndo":
				p.correr(onde, lerp_angle(float(pa["rumo"]), float(pb["rumo"]), u), float(_piloto_fuga.get("v_ms", 2.8)))
			"levantando":
				p.levantar(onde, float(_piloto_fuga.get("levantar_s", 1.68)))
				p.correr(onde, float(pb["rumo"]), 0.0)
			"fora":
				p.correr(onde, float(pb["rumo"]), float(_piloto_fuga.get("v_ms", 2.8)))
				_piloto_fora[id] = PILOTO_SAI_S


## Depois da última amostra (a luta acabou e a cena segue atrás do
## resultado): o piloto continua sozinho, com as regras da simulação, até sair
## da arena; caído, levanta no tempo dela. Só tela.
func _piloto_sozinho(id: String, p: Piloto3D, delta: float) -> void:
	var v := float(_piloto_fuga.get("v_ms", 2.8))
	match p.estado:
		"caido":
			var caido := float(p.get_meta("caido_s", 0.0)) + delta
			p.set_meta("caido_s", caido)
			if caido >= float(_piloto_fuga.get("caido_s", 3.0)):
				var q := p.posicao_corpo()
				p.levantar(Vector3(q.x, _forma.altura(Vector2(q.x, -q.z)), q.z),
						float(_piloto_fuga.get("levantar_s", 1.68)))
		"correndo":
			var pos := Vector2(p.global_position.x, -p.global_position.z)
			var pm := _forma.muro_perto(pos)
			if float(pm[0]) <= float(_piloto_fuga.get("saida_m", 0.5)):
				_piloto_fora[id] = PILOTO_SAI_S
				return
			var dir: Vector2 = -(pm[1] as Vector2)
			pos += dir * v * delta
			p.correr(Vector3(pos.x, _forma.altura(pos), -pos.y), dir.angle(), v)


## A proteção da região atingida sai do carro e cai no chão, rolando.
func _soltar(e: Dictionary) -> void:
	var c = _carros.get(e["carro"])
	if not c is CarroBloco or float(e["dano"]) < SOLTA_DANO:
		return
	var regiao := String(PROTECAO_DA_REGIAO.get(String(e.get("regiao", "")), ""))
	var no: Node3D = (c as CarroBloco).soltar_protecao(regiao, _cena) if regiao != "" else null
	if no == null:
		return
	var fora: Vector3 = no.global_position - (c as Node3D).global_position
	fora.y = 0.0
	fora = fora.normalized() if fora.length() > 0.01 else Vector3.RIGHT
	_soltas.append({"no": no, "v": fora * 4.0 + Vector3.UP * 3.5, "giro": Vector3(randf_range(-6, 6), randf_range(-3, 3),
			randf_range(-6, 6))})


func _cair_soltas(delta: float) -> void:
	for s in _soltas:
		var no: Node3D = s["no"]
		if not is_instance_valid(no) or s.get("parada", false):
			continue
		s["v"] = (s["v"] as Vector3) + Vector3.DOWN * 9.8 * delta
		no.global_position += (s["v"] as Vector3) * delta
		no.rotation += (s["giro"] as Vector3) * delta
		var chao := _forma.altura(Vector2(no.global_position.x, -no.global_position.z)) + 0.15
		if no.global_position.y <= chao:
			no.global_position.y = chao
			s["v"] = (s["v"] as Vector3) * Vector3(0.4, -0.25, 0.4)
			s["giro"] = (s["giro"] as Vector3) * 0.4
			if (s["v"] as Vector3).length() < 0.6:
				s["parada"] = true


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
	f.scale_amount_min = 0.5
	f.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)  # faísca pequena (perto da câmera, 0,2 m virava quadrado grande)
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
	_objetos = ObjetosArena.new()
	_cena.add_child(_objetos)
	var lados := _lados_arquibancada()
	_objetos.lados_ocupados = lados
	_objetos.montar(_forma, hash(_forma.muro))
	_montar_arquibancadas(lados)
	var cenario := CenarioArena.new()
	_cena.add_child(cenario)
	cenario.montar(_forma, _bloco_mn, _bloco_lado, lados, _objetos.trechos_concreto, hash(_forma.muro) + 1)
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
	# Bloco quadrado (maquete): o lado é a maior largura do muro mais a margem.
	var lado := ceilf(maxf(mx.x - mn.x, mx.y - mn.y) + CHAO_MARGEM_M * 2.0)
	mn = (mn + mx) * 0.5 - Vector2.ONE * lado * 0.5
	mx = mn + Vector2.ONE * lado
	_bloco_mn = mn
	_bloco_lado = lado
	var nx := int(ceil((mx.x - mn.x) / CHAO_PASSO_M))
	var ny := int(ceil((mx.y - mn.y) / CHAO_PASSO_M))
	var alturas := PackedFloat32Array()
	alturas.resize((nx + 1) * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			alturas[j * (nx + 1) + i] = _forma.altura(mn + Vector2(i, j) * CHAO_PASSO_M)
	# Terra da arena até um pouco além do muro (barreira e alambrado); dali
	# para fora, grama. A troca é por vértice, misturando as cores numa faixa
	# (por quadrado da grade, a divisa saía em degraus).
	var grama := PackedFloat32Array()
	grama.resize((nx + 1) * (ny + 1))
	for j in ny + 1:
		for i in nx + 1:
			var d := -float(_forma.muro_perto(mn + Vector2(i, j) * CHAO_PASSO_M)[0])  # > 0 fora
			grama[j * (nx + 1) + i] = smoothstep(GRAMA_DEPOIS_DO_MURO_M - GRAMA_FAIXA_M, GRAMA_DEPOIS_DO_MURO_M + GRAMA_FAIXA_M, d)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.025
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
				# Encosta íngreme (parede de vala, queda de rampa, pé de degrau) mais
				# escura; topo dos platôs mais claro e fundo das valas mais escuro:
				# o relevo se lê de longe.
				var luz := clampf(0.62 + 0.55 * nrm.dot(LUZ_CHAO), 0.45, 1.25) * clampf(1.0 + h * 0.11, 0.62, 1.22) \
						* lerpf(0.55, 1.0, pow(nrm.y, 6.0))
				var tom := COR_GRAMA.lerp(COR_GRAMA_CLARA, clampf(ruido.get_noise_2dv(q) * 0.9 + 0.5, 0.0, 1.0))
				st.set_color(COR_TERRA.lerp(tom, grama[cj * (nx + 1) + ci]) * luz)
				st.set_uv((q - mn) / lado)
				st.add_vertex(Vector3(q.x, h, -q.y))
	st.generate_normals()
	var chao := MeshInstance3D.new()
	chao.mesh = st.commit()
	# A textura (manchas e rastros) clareia e escurece a terra e a grama.
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.albedo_texture = _textura_terra(mn, lado)
	mt.roughness = 0.95
	chao.material_override = mt
	_cena.add_child(chao)
	_chao_fisico(mn, nx, ny, alturas)


## Manchas de terra úmida e seca (ruído em camadas, nativo e rápido) e rastros
## de pneu em arco, como de carros rodando: pares de linhas mais escuras.
func _textura_terra(mn: Vector2, lado: float) -> ImageTexture:
	var ruido := FastNoiseLite.new()
	ruido.seed = hash(_forma.muro)
	ruido.frequency = 0.004
	ruido.fractal_octaves = 5
	ruido.fractal_gain = 0.55
	var img := ruido.get_image(TERRA_PX, TERRA_PX)
	img.convert(Image.FORMAT_RGB8)
	img.adjust_bcs(1.5, 0.42, 1.0)  # claro e pouco contraste: manchas, não buracos
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_forma.muro) + 7
	var px := TERRA_PX / lado
	for k in MARCAS:
		var centro := _forma.largada(rng.randf() * TAU, rng.randf_range(0.0, 0.7))
		var raio := rng.randf_range(5.0, 18.0)
		var a0 := rng.randf() * TAU
		var arco := rng.randf_range(1.5, 4.5)
		var passos := int(raio * arco / 0.2)
		for t in passos:
			var ang := a0 + arco * float(t) / passos
			var dir := Vector2.from_angle(ang)
			for lado_pneu in [-0.8, 0.8]:
				var q: Vector2 = centro + dir * (raio + float(lado_pneu))
				if not _forma.dentro(q):
					continue
				var x := int((q.x - mn.x) * px)
				var y := int((q.y - mn.y) * px)
				for dx in 2:
					for dy in 2:
						var xx := clampi(x + dx, 0, TERRA_PX - 1)
						var yy := clampi(y + dy, 0, TERRA_PX - 1)
						img.set_pixel(xx, yy, img.get_pixel(xx, yy) * 0.95)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Corpo cinemático do carro na física de tela: segue a simulação e empurra o
## piloto caído e os objetos da arena (que não mudam o resultado).
func _corpo_fisico(c: Node3D) -> AnimatableBody3D:
	var dim: Vector2 = (c as CarroBloco).dimensoes() if c is CarroBloco else Vector2(Arena.COMPRIMENTO_M, Arena.LARGURA_M)
	var corpo := AnimatableBody3D.new()
	corpo.collision_layer = CAMADA_CARRO
	corpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(dim.x, 1.2, dim.y)
	cs.shape = caixa
	cs.position.y = 0.7
	corpo.add_child(cs)
	c.add_child(corpo)
	return corpo


## O mesmo chão para a física de tela (ragdoll do piloto, destroços e objetos
## da arena): camada 1, como no pacote de dano. A simulação não usa.
func _chao_fisico(mn: Vector2, nx: int, ny: int, alturas: PackedFloat32Array) -> void:
	var forma := HeightMapShape3D.new()
	forma.map_width = nx + 1
	forma.map_depth = ny + 1
	var dados := PackedFloat32Array()
	dados.resize((nx + 1) * (ny + 1))
	# Linhas do mapa crescem em +Z do mundo, que é −Y da simulação.
	for jz in ny + 1:
		for i in nx + 1:
			dados[jz * (nx + 1) + i] = alturas[(ny - jz) * (nx + 1) + i]
	forma.map_data = dados
	var corpo := StaticBody3D.new()
	corpo.collision_layer = CAMADA_CHAO
	corpo.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = forma
	cs.scale = Vector3.ONE * CHAO_PASSO_M
	corpo.add_child(cs)
	corpo.position = Vector3(mn.x + nx * CHAO_PASSO_M * 0.5, 0.0, -(mn.y + ny * CHAO_PASSO_M * 0.5))
	_cena.add_child(corpo)


## Pilhas de pneus nos cantos do muro, entre a barreira e o alambrado (a
## barreira contínua é do CenarioArena), e os anéis de pneus das ilhas.
func _pneus_muro() -> void:
	var pontos := []  # [posição 3D, colorido]
	var n := _forma.muro.size()
	for i in n:
		var q := _forma.muro[i]
		var fora := ((q - _forma.muro[(i - 1 + n) % n]).normalized().orthogonal()
				+ (_forma.muro[(i + 1) % n] - q).normalized().orthogonal()).normalized()
		var lado := fora.orthogonal()
		for coluna in [[-0.65, 3], [0.65, 2]]:
			var p: Vector2 = q + fora * 1.1 + lado * float(coluna[0])
			if _atras_do_concreto(p):
				continue
			for andar in int(coluna[1]):
				pontos.append([Vector3(p.x, _forma.altura(p) + 0.18 + andar * 0.36, -p.y), andar == 1 and i % 2 == 0])
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


# --- Arquibancadas -----------------------------------------------------------------

const ARQUIBANCADA := preload("res://visual/arquibancada/arquibancada.tscn")
const MODULO_M := 6.0  # largura de um bloco do pacote
const ARQUIBANCADA_LADOS := 3  # os lados mais compridos do muro
const ARQUIBANCADA_MODULOS_MAX := 4
## Da linha do muro até a origem do bloco: os pneus (até ~2,5 m) e o muro
## frontal do pacote (face a 1 m da origem).
const ARQUIBANCADA_RECUO_M := 4.2
const OLA_ATRASO_S := 1.76  # entre blocos vizinhos (pacote)
const OLA_INICIO_S := 2.0
const TORCIDA_DANO := 0.12  # batida entre carros que levanta a arquibancada mais perto
const FUGA_DANO := 0.1  # batida no muro que espanta quem está atrás
const FUGA_PERTO_M := 9.0
## Ocupação do pacote (0 meio vazio, 1 semi cheio, 2 cheio) pela licença da arena.
const LOTACAO := {"CLUB": 0, "SPORT": 1, "NATIONAL": 1, "INTERNATIONAL": 2, "PRO": 2, "ELITE": 2}
var _lotacao := 1
## Grama fora do muro (a faixa antes dela é a terra da barreira e do alambrado).
const GRAMA_DEPOIS_DO_MURO_M := 2.4
const GRAMA_FAIXA_M := 0.9  # meia largura da mistura terra/grama
const COR_GRAMA := Color(0.38, 0.52, 0.29)
const COR_GRAMA_CLARA := Color(0.47, 0.6, 0.32)
## Terra da arena: cor base (a textura gerada só clareia e escurece) e a
## textura, um pixel a cada lado/TERRA_PX m, com as marcas de pneu.
const COR_TERRA := Color(0.66, 0.5, 0.36)
const TERRA_PX := 512
const MARCAS := 10  # rastros em arco (pares de pneus) pintados no chão
## Quadrado do bloco de terreno (2D): canto mínimo e lado.
var _bloco_mn := Vector2.ZERO
var _bloco_lado := 0.0


## Índices dos lados do muro que recebem arquibancada: os mais compridos que
## cabem pelo menos um bloco.
func _lados_arquibancada() -> Array:
	var n := _forma.muro.size()
	var lados := []
	for i in n:
		var comp := (_forma.muro[(i + 1) % n] - _forma.muro[i]).length()
		if comp >= MODULO_M + 2.0:
			lados.append([comp, i])
	lados.sort_custom(func(x, y): return x[0] > y[0])
	return lados.slice(0, ARQUIBANCADA_LADOS).map(func(x): return x[1])


## Blocos encostados, centrados no lado, de frente para o centro da arena; o
## primeiro e o último fecham as pontas (left_end/right_end do pacote). A ola
## corre por todos, um bloco depois do outro.
func _montar_arquibancadas(lados: Array) -> void:
	_arquibancadas = []
	var n := _forma.muro.size()
	var ordem := 0
	for i in lados:
		var a := _forma.muro[i]
		var b := _forma.muro[(i + 1) % n]
		var fora := (b - a).normalized().orthogonal()
		var mods := mini(int(((b - a).length() - 2.0) / MODULO_M), ARQUIBANCADA_MODULOS_MAX)
		var meio := a.lerp(b, 0.5) + fora * ARQUIBANCADA_RECUO_M
		var dentro := Vector3(-fora.x, 0.0, fora.y)  # para o centro, no mundo (y 2D = −z)
		var base := Basis.looking_at(dentro, Vector3.UP)  # o público olha para −Z
		var chao := _forma.altura(meio)
		var blocos := []
		for k in mods:
			var bloco: Node3D = ARQUIBANCADA.instantiate()
			bloco.left_end = k == 0
			bloco.right_end = k == mods - 1
			bloco.occupancy = _lotacao
			bloco.crowd_seed = hash([i, k])
			bloco.transform = Transform3D(base, Vector3(meio.x, chao, -meio.y) + base.x * (k - (mods - 1) * 0.5) * MODULO_M)
			_cena.add_child(bloco)
			bloco.start_wave(OLA_INICIO_S + ordem * OLA_ATRASO_S)
			ordem += 1
			blocos.append(bloco)
		_arquibancadas.append({"blocos": blocos, "a": a, "b": b, "fora": fora})


func _comemorar_todas() -> void:
	for arq in _arquibancadas:
		for bloco in arq["blocos"]:
			bloco.celebrate()


## A arquibancada do lado mais perto de `q` (2D) e a distância até o lado.
func _arquibancada_perto(q: Vector2) -> Array:
	var melhor: Dictionary = {}
	var dist := INF
	for arq in _arquibancadas:
		var d := q.distance_to(Geometry2D.get_closest_point_to_segment(q, arq["a"], arq["b"]))
		if d < dist:
			dist = d
			melhor = arq
	return [melhor, dist]


## Batida forte entre carros: a arquibancada mais perto comemora. Batida forte
## no muro (sem outro carro) bem na frente dela: quem está atrás foge pela
## escada da ponta (fuga do pacote; não voltam até a próxima luta).
func _reagir_publico(e: Dictionary, q: Vector2) -> void:
	if _arquibancadas.is_empty():
		return
	var perto := _arquibancada_perto(q)
	var dano := float(e["dano"])
	if String(e.get("por", "")) != "":
		if dano >= TORCIDA_DANO:
			for bloco in perto[0]["blocos"]:
				bloco.celebrate()
		return
	if dano < FUGA_DANO or float(perto[1]) > FUGA_PERTO_M:
		return
	var blocos: Array = perto[0]["blocos"]
	var saida: Vector3 = blocos.back().global_transform * Vector3(3.43, 0.0, 2.7)
	for bloco in blocos:
		var frente: Vector3 = bloco.global_transform * Vector3(0.0, bloco.elevation, 0.4)
		var alvo := Vector3(q.x, frente.y, -q.y)
		if frente.distance_to(alvo) < MODULO_M + ARQUIBANCADA_RECUO_M:
			bloco.crowd.flee_from(bloco.global_transform * Vector3(clampf(bloco.to_local(alvo).x, -2.5, 2.5), bloco.elevation, 0.5), saida)


## Trecho do muro com barreira de concreto (ObjetosArena): sem pneus atrás.
func _atras_do_concreto(q: Vector2) -> bool:
	for tr in _objetos.trechos_concreto:
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, tr[0], tr[1])) < 2.0:
			return true
	return false


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


## Canhão d'água dos pesados que têm um (Pesados.extras): mostra o jato no
## carro que a simulação diz que leva água (Arena._canhoes, que empurra); sem
## esse dado (luta antiga), mira o rival vivo mais perto.
const CANHAO_ALCANCE_M := 20.0
const CANHAO_GIRO := 2.5  # rad/s


func _canhoes(amostra: Dictionary, delta: float) -> void:
	for id in _carros:
		var c: Node3D = _carros[id]
		var canhao := c.find_child("Canhao", true, false) as Node3D
		if canhao == null:
			continue
		var jato := canhao.get_node_or_null("Jato") as CPUParticles3D
		var alvo: Variant = null
		var da_sim: bool = amostra[id].has("jato")  # a simulação diz quem leva água
		if da_sim:
			alvo = _carros.get(String(amostra[id]["jato"]))
		elif not bool(amostra[id]["eliminado"]):
			var melhor := CANHAO_ALCANCE_M
			for outro in _carros:
				if outro == id or bool(amostra[outro]["eliminado"]):
					continue
				var d: float = c.global_position.distance_to(_carros[outro].global_position)
				if d < melhor:
					melhor = d
					alvo = _carros[outro]
		var mirando := false
		if alvo != null:
			var local: Vector3 = canhao.get_parent().to_local((alvo as Node3D).global_position) - canhao.position
			var quer := atan2(local.x, local.z)
			canhao.rotation.y = rotate_toward(canhao.rotation.y, quer, CANHAO_GIRO * delta) if delta > 0.0 else quer
			mirando = da_sim or absf(angle_difference(canhao.rotation.y, quer)) < 0.25
		if jato != null and jato.emitting != mirando:
			jato.emitting = mirando
			for nevoa in jato.get_children():
				(nevoa as CPUParticles3D).emitting = mirando
		_arco_do_jato(canhao, jato, alvo as Node3D if mirando else null)


## O jato contínuo: uma faixa macia (borda transparente) no arco da água, do
## bocal até a altura do alvo, com a velocidade de saída e a gravidade, mais o
## respingo onde ela bate. Refeita a cada quadro, virada para a câmera.
func _arco_do_jato(canhao: Node3D, jato: Node3D, alvo: Node3D) -> void:
	var arco := canhao.get_node_or_null("ArcoJato") as MeshInstance3D
	var resp := canhao.get_node_or_null("Respingo") as CPUParticles3D
	if arco == null:
		arco = MeshInstance3D.new()
		arco.name = "ArcoJato"
		arco.top_level = true
		arco.mesh = ImmediateMesh.new()
		arco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		arco.material_override = mat
		canhao.add_child(arco)
		resp = Pesados.respingo()
		canhao.add_child(resp)
	if alvo == null or jato == null or _camera == null:
		arco.visible = false
		if resp.emitting:
			resp.emitting = false
			for b in resp.get_children():
				(b as CPUParticles3D).emitting = false
		return
	arco.visible = true
	var p0: Vector3 = jato.global_position
	var dir: Vector3 = (canhao.global_transform.basis * Vector3(0, sin(Pesados.CANHAO_INCL), cos(Pesados.CANHAO_INCL))).normalized()
	var g := Vector3(0, -9.8, 0)
	var chao: float = alvo.global_position.y + 0.7
	# força do jato para cair no alvo (ângulo da lança fixo):
	# v² = g·d² / (2·cos²θ·(d·tanθ + h)), h = altura do bocal sobre o alvo
	var plano := Vector2(alvo.global_position.x - p0.x, alvo.global_position.z - p0.z)
	var d := plano.length()
	var th: float = Pesados.CANHAO_INCL
	var h := p0.y - chao
	var vel := Pesados.JATO_V
	var den := 2.0 * cos(th) * cos(th) * (d * tan(th) + h)
	if den > 0.01:
		vel = clampf(sqrt(9.8 * d * d / den), 4.0, Pesados.JATO_V + 4.0)
	var v := dir * vel
	if jato is CPUParticles3D:
		var cp := jato as CPUParticles3D
		cp.initial_velocity_min = vel - 1.0
		cp.initial_velocity_max = vel + 0.5
		for nv in cp.get_children():
			(nv as CPUParticles3D).initial_velocity_min = vel * 0.7
			(nv as CPUParticles3D).initial_velocity_max = vel * 0.95
	var pts := []
	var t := 0.0
	while t < 1.8:
		var p := p0 + v * t + g * (0.5 * t * t)
		pts.append(p)
		if p.y < chao and t > 0.1:
			break
		t += 0.04
	var im := arco.mesh as ImmediateMesh
	im.clear_surfaces()
	if pts.size() < 2:
		return
	var agora := Time.get_ticks_msec() / 1000.0
	var olho: Vector3 = _camera.global_position
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var antes := []
	for i in pts.size():
		var p: Vector3 = pts[i]
		var tan: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var lado := tan.cross(olho - p).normalized()
		var u := float(i) / (pts.size() - 1)
		var w := lerpf(0.1, 0.65, u) * (1.0 + 0.18 * sin(agora * 31.0 + i * 1.7))
		var a := lerpf(0.85, 0.35, u)
		var faixa := [[p - lado * w, 0.0], [p, a], [p + lado * w, 0.0]]
		if not antes.is_empty():
			for k in 2:
				var q0: Array = antes[k]
				var q1: Array = antes[k + 1]
				var r0: Array = faixa[k]
				var r1: Array = faixa[k + 1]
				for vtx in [q0, r0, r1, q0, r1, q1]:
					im.surface_set_color(Color(0.9, 0.96, 1.0, vtx[1]))
					im.surface_add_vertex(vtx[0])
		antes = faixa
	im.surface_end()
	resp.global_position = pts[-1]
	if not resp.emitting:
		resp.emitting = true
		for b in resp.get_children():
			(b as CPUParticles3D).emitting = true
