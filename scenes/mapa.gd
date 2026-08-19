extends Node2D
## Módulo 3 — Mapa. Instancia um Lote por edifício de Vila.edificios, nas posições
## fixas de vila_lotes.json. especificacao_tecnica_v1.md #6-11: projeção isométrica,
## zoom limitado 0.8x-1.6x, YSort automático via CanvasItem "ysort_enabled".

const LOTE_SCENE := preload("res://scenes/lote.tscn")
const TELA_ALDEOES_SCENE := preload("res://scenes/tela_aldeoes.tscn")
const ZOOM_MIN := 0.8
const ZOOM_MAX := 1.6

@onready var _camera: Camera2D = $Camera2D
@onready var _lotes_root: Node2D = $Lotes
@onready var _debug_label: Label = $HudLayer/DebugLabel
@onready var _botao_aldeoes: Button = $HudLayer/BotaoAldeoes

var _zoom_atual := 1.0
var _tela_aldeoes: CanvasLayer = null


func _ready() -> void:
	var lotes_json: Dictionary = Dados.vila_lotes()
	var tile := Vector2i(lotes_json["tile"]["w"], lotes_json["tile"]["h"])

	var bounds_min := Vector2.INF
	var bounds_max := -Vector2.INF
	for id in Vila.edificios:
		var e: Edificio = Vila.edificios[id]
		var pos := Iso.cell_to_pos(e.celula, tile)
		var lote := LOTE_SCENE.instantiate()
		lote.position = pos
		_lotes_root.add_child(lote)
		lote.configurar(id, tile)
		bounds_min = bounds_min.min(pos)
		bounds_max = bounds_max.max(pos)

	if bounds_min.x != INF:
		_camera.position = (bounds_min + bounds_max) / 2.0
	_aplicar_zoom()
	_camera.make_current()

	Sim.fase_mudou.connect(func(_f): _atualizar_debug())
	Sim.dia_mudou.connect(func(_d): _atualizar_debug())
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(_atualizar_debug)
	add_child(t)
	t.start()
	_atualizar_debug()

	_botao_aldeoes.pressed.connect(_toggle_tela_aldeoes)


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
	_debug_label.text = "dia %d · %s · ato %d\ncomida %.1f · madeira %.1f · tecido %.1f · ouro %.1f\nfome %.1f (teto dep. %d)\naldeões %d (Lar %d/%d · Alojamento %d/%d)" % [
		Sim.dia_vila, Sim.nome_fase(Sim.fase_dia), Sim.ato,
		r["comida"], r["madeira"], r["tecido"], r["ouro"],
		Economia.indice_fome, Economia.teto_deposito(),
		Populacao.orfaos.size(),
		Populacao.contar_estado(Orfao.Estado.CRIANCA), Populacao.capacidade_lar(),
		Populacao.contar_estado(Orfao.Estado.ADULTO_OCIOSO) + Populacao.contar_estado(Orfao.Estado.ALOCADO), Populacao.capacidade_alojamento(),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_atual = clampf(_zoom_atual + 0.1, ZOOM_MIN, ZOOM_MAX)
			_aplicar_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_atual = clampf(_zoom_atual - 0.1, ZOOM_MIN, ZOOM_MAX)
			_aplicar_zoom()
