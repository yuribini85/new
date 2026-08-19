extends Node2D
## Módulo 3 — Mapa. Módulo 6 — Rotas e Floresta. docs/mecanicas_para_godot.md #4-5.
## Instancia um Lote por edifício, desenha a floresta e anima trabalhadores indo ao
## Depósito. Tudo isso é apresentação — não influencia número nenhum (a produção real
## é calculada pela Economia por segundo, sem depender de sprite ou trajeto).

const LOTE_SCENE := preload("res://scenes/lote.tscn")
const TELA_ALDEOES_SCENE := preload("res://scenes/tela_aldeoes.tscn")
const TELA_EXPEDICAO_SCENE := preload("res://scenes/tela_expedicao.tscn")
const TELA_MERCADO_SCENE := preload("res://scenes/tela_mercado.tscn")
const PERSONAGEM_SCENE := preload("res://scenes/personagem.tscn")
const ZOOM_MAX := 1.6

const COR_ARVORE_DE_PE := Color(0.22, 0.4, 0.2)
const COR_ARVORE_TOCO := Color(0.32, 0.22, 0.14)
const COR_ROTA := Color(0.85, 0.75, 0.4)
const RAIO_CORTESIA := 40.0  # px em espaço de mundo; agentes mais perto que isso cedem

const COR_CRIANCA := Color(0.5, 0.65, 0.85)
const COR_OCIOSO := Color(0.6, 0.6, 0.6)
const COR_ALOCADO := Color(0.45, 0.75, 0.45)
const COR_LIDER := Color(0.85, 0.7, 0.3)

@onready var _camera: Camera2D = $Camera2D
@onready var _lotes_root: Node2D = $Lotes
@onready var _floresta_root: Node2D = $Floresta
@onready var _rotas_root: Node2D = $Rotas
@onready var _personagens_root: Node2D = $Personagens
@onready var _debug_label: Label = $HudLayer/DebugLabel
@onready var _botao_aldeoes: Button = $HudLayer/BotaoAldeoes
@onready var _botao_expedicao: Button = $HudLayer/BotaoExpedicao
@onready var _botao_mercado: Button = $HudLayer/BotaoMercado

var _zoom_atual := 1.0
var _zoom_min := 0.15  # especificacao_tecnica_v1.md#4 previa 0.8; recalculado em
                        # _ready() pra sempre caber a vila inteira, seja qual for
                        # o tamanho real dela.
var _tela_aldeoes: CanvasLayer = null
var _tela_expedicao: CanvasLayer = null
var _tela_mercado: CanvasLayer = null
var _arrastando := false
var _ultimo_mouse_pos := Vector2.ZERO
var _tile: Vector2i
var _timers_rota: Dictionary = {}  # edificio_id -> float acumulado
var _timer_rota_lenhador: float = 0.0
var _proximo_walker_id := 0
var _lote_nodes: Dictionary = {}  # edificio_id -> Node2D (Lote)
var _distancia_arrasto := 0.0  # para distinguir toque/clique de arrasto real
var _walkers_ativos: Dictionary = {}  # id -> posição atual (para cortesia)
var _personagem_nodes: Dictionary = {}  # chave -> Node2D
var _personagem_alvo: Dictionary = {}  # chave -> Vector2 (último destino conhecido)
var _personagem_tweens: Dictionary = {}  # chave -> Tween (caminhada em curso)


func _ready() -> void:
	var lotes_json: Dictionary = Dados.vila_lotes()
	_tile = Vector2i(lotes_json["tile"]["w"], lotes_json["tile"]["h"])

	var bounds_min := Vector2.INF
	var bounds_max := -Vector2.INF
	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		var pos := Iso.cell_to_pos(e.celula, _tile)
		var pos_oposta := pos + Iso.cell_to_pos(e.footprint, _tile)  # canto oposto do footprint
		var lote := LOTE_SCENE.instantiate()
		lote.position = pos
		_lotes_root.add_child(lote)
		lote.configurar(id, _tile)
		_lote_nodes[id] = lote
		bounds_min = bounds_min.min(pos).min(pos_oposta)
		bounds_max = bounds_max.max(pos).max(pos_oposta)

	if bounds_min.x != INF:
		_camera.position = (bounds_min + bounds_max) / 2.0
	_aplicar_zoom()
	_camera.make_current()

	if bounds_min.x != INF:
		# Espera o viewport assentar no tamanho final antes de calcular o zoom que
		# cabe a vila inteira.
		await get_tree().process_frame
		await get_tree().process_frame
		var span := bounds_max - bounds_min
		var viewport_size := get_viewport().get_visible_rect().size
		# Camera2D.zoom do Godot: valor MAIOR = mais PRÓXIMO (confirmado por teste
		# direto — é o oposto do que a documentação sugere à primeira leitura).
		# Pra caber `span` mundo dentro de `viewport_size` tela, zoom = viewport/span.
		var zoom_para_caber := minf(viewport_size.x / span.x, viewport_size.y / span.y) / 1.15
		_zoom_min = minf(_zoom_min, zoom_para_caber)
		_zoom_atual = clampf(zoom_para_caber, _zoom_min, ZOOM_MAX)
		_aplicar_zoom()

	Sim.fase_mudou.connect(func(_f): _atualizar_debug())
	Sim.dia_mudou.connect(func(_d): _atualizar_debug())
	Sim.tick.connect(_on_tick)
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_atualizar_debug)
	add_child(t)
	t.start()
	_atualizar_debug()
	_redesenhar_floresta()

	_botao_aldeoes.pressed.connect(_toggle_tela_aldeoes)
	_botao_expedicao.pressed.connect(_toggle_tela_expedicao)
	_botao_mercado.pressed.connect(_toggle_tela_mercado)


func _toggle_tela_expedicao() -> void:
	if _tela_expedicao != null:
		_tela_expedicao.queue_free()
		_tela_expedicao = null
		return
	_tela_expedicao = TELA_EXPEDICAO_SCENE.instantiate()
	add_child(_tela_expedicao)


func _toggle_tela_mercado() -> void:
	if _tela_mercado != null:
		_tela_mercado.queue_free()
		_tela_mercado = null
		return
	_tela_mercado = TELA_MERCADO_SCENE.instantiate()
	add_child(_tela_mercado)


func _on_tick() -> void:
	_redesenhar_floresta()
	_processar_rotas()
	_processar_rota_lenhador()
	_atualizar_personagens()


func _centro_edificio(e: Edificio) -> Vector2:
	return Iso.cell_to_pos(e.celula, _tile) + Iso.cell_to_pos(e.footprint, _tile) / 2.0


## Um token por líder (um por prédio construído) e por órfão — posicionado onde ele
## está agora (Lar, Alojamento ou local de trabalho). Atualiza posição sem recriar
## os tokens que já existem, para não reiniciar a animação idle deles a cada tick.
func _atualizar_personagens() -> void:
	var desejados: Dictionary = {}  # chave -> {pos, cor}

	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		if e.nivel > 0:
			desejados["lider_%s" % id] = {"pos": _centro_edificio(e), "cor": COR_LIDER}

	for id in Populacao.orfaos:
		var o: Orfao = Populacao.orfaos[id]
		var alvo_edificio := ""
		var cor := COR_OCIOSO
		match o.estado:
			Orfao.Estado.CRIANCA:
				alvo_edificio = "lar_dos_orfaos"
				cor = COR_CRIANCA
			Orfao.Estado.ADULTO_OCIOSO:
				alvo_edificio = "alojamento"
				cor = COR_OCIOSO
			Orfao.Estado.ALOCADO:
				alvo_edificio = o.local_id
				cor = COR_ALOCADO
			_:
				continue  # EM_EXPEDICAO / MORTO: fora do mapa

		if not Vila.edificios.has(alvo_edificio):
			continue
		var base := _centro_edificio(Vila.edificios[alvo_edificio])
		var jitter := Vector2((abs(hash(id)) % 50) - 25, (abs(hash(id + "y")) % 30) - 15)
		desejados[id] = {"pos": base + jitter, "cor": cor}

	for chave in _personagem_nodes.keys():
		if not desejados.has(chave):
			if _personagem_tweens.has(chave):
				_personagem_tweens[chave].kill()
				_personagem_tweens.erase(chave)
			_personagem_nodes[chave].queue_free()
			_personagem_nodes.erase(chave)
			_personagem_alvo.erase(chave)

	for chave in desejados:
		var info: Dictionary = desejados[chave]
		if not _personagem_nodes.has(chave):
			var node := PERSONAGEM_SCENE.instantiate()
			_personagens_root.add_child(node)
			node.configurar(info["cor"])
			node.position = info["pos"]
			_personagem_nodes[chave] = node
			_personagem_alvo[chave] = info["pos"]
			continue

		# Só anima a caminhada quando o alvo muda de verdade (ex.: órfão mudou de
		# prédio) — o jitter em si é estável entre ticks, então isso não dispara
		# a cada tick à toa.
		var alvo_anterior: Vector2 = _personagem_alvo.get(chave, info["pos"])
		if alvo_anterior.distance_to(info["pos"]) < 1.0:
			continue

		_personagem_alvo[chave] = info["pos"]
		if _personagem_tweens.has(chave):
			_personagem_tweens[chave].kill()
		var node = _personagem_nodes[chave]
		var tw := create_tween()
		tw.tween_property(node, "position", info["pos"], 1.2).set_trans(Tween.TRANS_SINE)
		_personagem_tweens[chave] = tw


func _redesenhar_floresta() -> void:
	for c in _floresta_root.get_children():
		c.queue_free()
	for a in Floresta.arvores:
		var pos: Vector2 = Iso.cell_to_pos(a.celula, _tile) + a.offset
		var poly := Polygon2D.new()
		if a.estado == Arvore.Estado.DE_PE:
			poly.color = COR_ARVORE_DE_PE
			poly.polygon = PackedVector2Array([Vector2(0, -18), Vector2(12, 10), Vector2(-12, 10)])
		else:
			poly.color = COR_ARVORE_TOCO
			poly.polygon = PackedVector2Array([Vector2(-6, -4), Vector2(6, -4), Vector2(6, 4), Vector2(-6, 4)])
		poly.position = pos
		_floresta_root.add_child(poly)


## Frequência proporcional ao número de trabalhadores do edifício (proxy de produção,
## sem acoplar ao número real — mecanicas_para_godot.md #4).
func _processar_rotas() -> void:
	if not Vila.edificios.has("deposito") or Vila.edificios["deposito"].nivel <= 0:
		return
	var catalogo := Dados.catalogo_edificios_ato1()

	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		if e.nivel <= 0 or id == "deposito":
			continue
		var produto: String = catalogo.get(id, {}).get("produz", "")
		if produto == "":
			continue

		var n := 1 + e.vagas_orfaos.filter(func(v): return v != null and v != "").size()
		var intervalo := 6.0 / float(n)

		_timers_rota[id] = _timers_rota.get(id, 0.0) + 1.0
		if _timers_rota[id] < intervalo:
			continue

		var origem := Iso.cell_to_pos(e.celula, _tile)
		if _tem_vizinho_perto(origem):
			continue  # cortesia: alguém está por perto, tenta de novo no próximo tick

		_timers_rota[id] = 0.0
		var deposito_pos := Iso.cell_to_pos(Vila.edificios["deposito"].celula, _tile)
		var borda := deposito_pos + Vector2(0, 40)  # borda, não o centro (mecanicas #4)
		_spawn_walker(origem, borda)


func _tem_vizinho_perto(pos: Vector2) -> bool:
	for id in _walkers_ativos:
		if _walkers_ativos[id].distance_to(pos) < RAIO_CORTESIA:
			return true
	return false


## Rota específica do lenhador: da cabana até a árvore que está sendo cortada agora
## (Floresta.arvore_alvo()), e volta — separada da entrega no Depósito (mecanicas #4).
func _processar_rota_lenhador() -> void:
	if not Vila.edificios.has(Floresta.CENTRO_ID) or Vila.edificios[Floresta.CENTRO_ID].nivel <= 0:
		return
	var alvo := Floresta.arvore_alvo()
	if alvo == null:
		return

	var n: int = Vila.edificios[Floresta.CENTRO_ID].n_trabalhadores()
	if n <= 0:
		return
	var intervalo := 6.0 / float(n)

	_timer_rota_lenhador += 1.0
	if _timer_rota_lenhador < intervalo:
		return

	var origem := Iso.cell_to_pos(Vila.edificios[Floresta.CENTRO_ID].celula, _tile)
	if _tem_vizinho_perto(origem):
		return  # cortesia: tenta de novo no próximo tick

	_timer_rota_lenhador = 0.0
	var destino: Vector2 = Iso.cell_to_pos(alvo.celula, _tile) + alvo.offset
	_spawn_walker(origem, destino)


## Caminho com curva (nunca reta convergente) da origem até o destino, e volta.
## mecanicas_para_godot.md #4.
func _spawn_walker(origem: Vector2, borda: Vector2) -> void:
	var walker_id := _proximo_walker_id
	_proximo_walker_id += 1

	var marcador := Polygon2D.new()
	marcador.color = COR_ROTA
	marcador.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	marcador.position = origem
	_rotas_root.add_child(marcador)
	_walkers_ativos[walker_id] = origem

	var meio := origem.lerp(borda, 0.5) + Vector2(borda.y - origem.y, origem.x - borda.x).normalized() * 30.0

	var tween := create_tween()
	tween.tween_method(func(p): marcador.position = p; _walkers_ativos[walker_id] = p, origem, meio, 0.8)
	tween.tween_method(func(p): marcador.position = p; _walkers_ativos[walker_id] = p, meio, borda, 0.8)
	tween.tween_method(func(p): marcador.position = p; _walkers_ativos[walker_id] = p, borda, meio, 0.8)
	tween.tween_method(func(p): marcador.position = p; _walkers_ativos[walker_id] = p, meio, origem, 0.8)
	tween.tween_callback(func():
		_walkers_ativos.erase(walker_id)
		marcador.queue_free()
	)


func _toggle_tela_aldeoes() -> void:
	if _tela_aldeoes != null:
		_tela_aldeoes.queue_free()
		_tela_aldeoes = null
		return
	_tela_aldeoes = TELA_ALDEOES_SCENE.instantiate()
	add_child(_tela_aldeoes)


func _aplicar_zoom() -> void:
	# Camera2D.zoom: maior valor = mais próximo (testado e confirmado). _zoom_atual
	# já representa isso diretamente, sem inversão.
	_camera.zoom = Vector2.ONE * _zoom_atual


func _atualizar_debug() -> void:
	var r := Economia.recursos
	var em_pe := 0
	for a in Floresta.arvores:
		if a.estado == Arvore.Estado.DE_PE:
			em_pe += 1
	_debug_label.text = "dia %d · %s · ato %d\ncomida %.1f · madeira %.1f · tecido %.1f · ouro %.1f · fôlego %.1f\nfome %.1f (teto dep. %d)\naldeões %d (Lar %d/%d · Alojamento %d/%d)\nfloresta %d/%d de pé · expedição: %s" % [
		Sim.dia_vila, Sim.nome_fase(Sim.fase_dia), Sim.ato,
		r["comida"], r["madeira"], r["tecido"], r["ouro"], r["folego"],
		Economia.indice_fome, Economia.teto_deposito(),
		Populacao.orfaos.size(),
		Populacao.contar_estado(Orfao.Estado.CRIANCA), Populacao.capacidade_lar(),
		Populacao.contar_estado(Orfao.Estado.ADULTO_OCIOSO) + Populacao.contar_estado(Orfao.Estado.ALOCADO), Populacao.capacidade_alojamento(),
		em_pe, Floresta.arvores.size(),
		"em curso" if Expedicoes.atual != null else ("relatório pronto" if not Expedicoes.ultimo_relatorio.is_empty() else "nenhuma"),
	]


## Converte posição de tela (espaço do viewport) em posição de mundo, considerando
## a posição e o zoom atuais da câmera.
func _tela_para_mundo(pos_tela: Vector2) -> Vector2:
	var centro := get_viewport().get_visible_rect().size / 2.0
	return _camera.position + (pos_tela - centro) / _camera.zoom


## Detecção de clique manual (sem Area2D/picking de física — mais simples de
## garantir e igual em desktop e touch).
func _tentar_construir_em(pos_tela: Vector2) -> void:
	var pos_mundo := _tela_para_mundo(pos_tela)
	for id in _lote_nodes:
		if _lote_nodes[id].contem_ponto_mundo(pos_mundo):
			Vila.construir(id)
			return


func _input(event: InputEvent) -> void:
	# _input, não _unhandled_input: mesmo sem Area2D nenhum, o picking de física do
	# viewport consome o clique antes de _unhandled_input vê-lo (testado). Pra não
	# construir "através" de um botão do HUD, checa se o mouse está sobre um
	# Control antes de tratar como clique no mapa.
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_atual = clampf(_zoom_atual + 0.1, _zoom_min, ZOOM_MAX)
			_aplicar_zoom()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_atual = clampf(_zoom_atual - 0.1, _zoom_min, ZOOM_MAX)
			_aplicar_zoom()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if get_viewport().gui_get_hovered_control() == null:
				_tentar_construir_em(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_arrastando = event.pressed
			_ultimo_mouse_pos = event.position
	elif event is InputEventMouseMotion and _arrastando:
		var delta: Vector2 = event.position - _ultimo_mouse_pos
		_camera.position -= delta / _camera.zoom
		_ultimo_mouse_pos = event.position
