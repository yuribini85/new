extends Node2D
## Representação visual de um lote/edifício no mapa. Placeholder geométrico —
## CLAUDE.md proíbe gerar arte; quando os assets de docs/NOMENCLATURA_ASSETS.md
## existirem, a Silhueta vira um Sprite2D com twb_bld_<id>_t<NN>.png.

const COR_RUINA := Color(0.16, 0.14, 0.13)
const COR_OBRA := Color(0.55, 0.47, 0.22)
const COR_PRONTO := Color(0.24, 0.42, 0.26)

@onready var _silhueta: Polygon2D = $Silhueta
@onready var _label: Label = $Label
@onready var _area: Area2D = $Area2D
@onready var _colisao: CollisionShape2D = $Area2D/CollisionShape2D

var edificio_id: String


func configurar(id: String, tile: Vector2i) -> void:
	edificio_id = id
	var e: Edificio = Vila.edificios[id]

	var meia_largura := e.footprint.x * tile.x / 2.0
	var meia_altura := e.footprint.y * tile.y / 2.0
	_silhueta.polygon = PackedVector2Array([
		Vector2(0, -meia_altura),
		Vector2(meia_largura, 0),
		Vector2(0, meia_altura),
		Vector2(-meia_largura, 0),
	])

	var forma := RectangleShape2D.new()
	forma.size = Vector2(meia_largura, meia_altura) * 1.6
	_colisao.shape = forma

	_area.input_event.connect(_on_input_event)
	Vila.edificio_iniciou_obra.connect(_on_edificio_mudou)
	Vila.edificio_construido.connect(_on_edificio_mudou)
	_atualizar()


func _on_edificio_mudou(id: String) -> void:
	if id == edificio_id:
		_atualizar()


func _atualizar() -> void:
	var e: Edificio = Vila.edificios[edificio_id]
	if e.em_obra:
		_silhueta.color = COR_OBRA
	elif e.nivel == Edificio.NIVEL_RUINA:
		_silhueta.color = COR_RUINA
	else:
		_silhueta.color = COR_PRONTO

	var status := "obra" if e.em_obra else ("ruína" if e.nivel == 0 else "nv %d" % e.nivel)
	_label.text = "%s\n(%s)" % [e.nome, status]


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Vila.construir(edificio_id)
