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


## A posição do nó (definida por quem instancia) já é a projeção isométrica da
## célula de origem do lote (canto, não centro). O contorno do losango precisa
## projetar os 4 cantos do footprint pela mesma transformação — usar largura/altura
## do footprint direto (sem projetar) desenha um losango com o ângulo errado para
## qualquer footprint que não seja 1x1. Iso.gd faz a mesma conta que Mapa usa para
## posicionar os lotes.
func configurar(id: String, tile: Vector2i) -> void:
	edificio_id = id
	var e: Edificio = Vila.edificios[id]

	var p00 := Vector2.ZERO
	var p10 := Iso.cell_to_pos(Vector2i(e.footprint.x, 0), tile)
	var p01 := Iso.cell_to_pos(Vector2i(0, e.footprint.y), tile)
	var p11 := Iso.cell_to_pos(e.footprint, tile)
	var centro := (p00 + p11) / 2.0

	_silhueta.polygon = PackedVector2Array([p00, p10, p11, p01])

	var forma := RectangleShape2D.new()
	forma.size = (p11 - p00).abs() * 0.8
	_colisao.position = centro
	_colisao.shape = forma
	_label.position = centro - _label.size / 2.0

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
