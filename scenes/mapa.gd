extends Node2D
## Módulo 3 — Mapa. Módulo 6 — Rotas e Floresta. docs/mecanicas_para_godot.md #4-5.
## Instancia um Lote por edifício, desenha a floresta e anima trabalhadores indo ao
## Depósito. Tudo isso é apresentação — não influencia número nenhum (a produção real
## é calculada pela Economia por segundo, sem depender de sprite ou trajeto).

const LOTE_SCENE := preload("res://scenes/lote.tscn")
const TELA_ALDEOES_SCENE := preload("res://scenes/tela_aldeoes.tscn")
const TELA_EXPEDICAO_SCENE := preload("res://scenes/tela_expedicao.tscn")
const ZOOM_MIN := 0.8
const ZOOM_MAX := 1.6

const COR_ARVORE_DE_PE := Color(0.22, 0.4, 0.2)
const COR_ARVORE_TOCO := Color(0.32, 0.22, 0.14)
const COR_ROTA := Color(0.85, 0.75, 0.4)
const RAIO_CORTESIA := 40.0  # px em espaço de mundo; agentes mais perto que isso cedem

@onready var _camera: Camera2D = $Camera2D
@onready var _lotes_root: Node2D = $Lotes
@onready var _floresta_root: Node2D = $Floresta
@onready var _rotas_root: Node2D = $Rotas
@onready var _debug_label: Label = $HudLayer/DebugLabel
@onready var _botao_aldeoes: Button = $HudLayer/BotaoAldeoes
@onready var _botao_expedicao: Button = $HudLayer/BotaoExpedicao

var _zoom_atual := 1.0
var _tela_aldeoes: CanvasLayer = null
var _tela_expedicao: CanvasLayer = null
var _tile: Vector2i
var _timers_rota: Dictionary = {}  # edificio_id -> float acumulado
var _proximo_walker_id := 0
var _walkers_ativos: Dictionary = {}  # id -> posição atual (para cortesia)


func _ready() -> void:
	var lotes_json: Dictionary = Dados.vila_lotes()
	_tile = Vector2i(lotes_json["tile"]["w"], lotes_json["tile"]["h"])

	var bounds_min := Vector2.INF
	var bounds_max := -Vector2.INF
	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		var pos := Iso.cell_to_pos(e.celula, _tile)
		var lote := LOTE_SCENE.instantiate()
		lote.position = pos
		_lotes_root.add_child(lote)
		lote.configurar(id, _tile)
		bounds_min = bounds_min.min(pos)
		bounds_max = bounds_max.max(pos)

	if bounds_min.x != INF:
		_camera.position = (bounds_min + bounds_max) / 2.0
	_aplicar_zoom()
	_camera.make_current()

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


func _toggle_tela_expedicao() -> void:
	if _tela_expedicao != null:
		_tela_expedicao.queue_free()
		_tela_expedicao = null
		return
	_tela_expedicao = TELA_EXPEDICAO_SCENE.instantiate()
	add_child(_tela_expedicao)


func _on_tick() -> void:
	_redesenhar_floresta()
	_processar_rotas()


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

		if _tem_vizinho_perto(Iso.cell_to_pos(e.celula, _tile)):
			continue  # cortesia: alguém está por perto, tenta de novo no próximo tick

		_timers_rota[id] = 0.0
		_spawn_walker(e.celula)


func _tem_vizinho_perto(pos: Vector2) -> bool:
	for id in _walkers_ativos:
		if _walkers_ativos[id].distance_to(pos) < RAIO_CORTESIA:
			return true
	return false


## Caminho com curva (nunca reta convergente) até a borda do Depósito, e volta.
## mecanicas_para_godot.md #4.
func _spawn_walker(origem_celula: Vector2i) -> void:
	var origem := Iso.cell_to_pos(origem_celula, _tile)
	var deposito_pos := Iso.cell_to_pos(Vila.edificios["deposito"].celula, _tile)
	var borda := deposito_pos + Vector2(0, 40)  # borda, não o centro (mecanicas #4)

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
	# Camera2D.zoom do Godot é invertido (maior valor = mais afastado); "zoom" aqui
	# é o fator de ampliação do jogador, então o mapeamento é 1/zoom_atual.
	_camera.zoom = Vector2.ONE / _zoom_atual


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_atual = clampf(_zoom_atual + 0.1, ZOOM_MIN, ZOOM_MAX)
			_aplicar_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_atual = clampf(_zoom_atual - 0.1, ZOOM_MIN, ZOOM_MAX)
			_aplicar_zoom()
