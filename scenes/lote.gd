extends Node2D
## Representação visual de um lote/edifício no mapa. Placeholder geométrico —
## CLAUDE.md proíbe gerar arte; quando os assets de docs/NOMENCLATURA_ASSETS.md
## existirem, a Silhueta vira um Sprite2D com twb_bld_<id>_t<NN>.png.

const COR_RUINA := Color(0.16, 0.14, 0.13)
const COR_OBRA := Color(0.55, 0.47, 0.22)
const COR_PRONTO := Color(0.24, 0.42, 0.26)

@onready var _silhueta: Polygon2D = $Silhueta
@onready var _label: Label = $Label

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
	_label.position = centro - _label.size / 2.0

	Vila.edificio_iniciou_obra.connect(_on_edificio_mudou)
	Vila.edificio_construido.connect(_on_edificio_mudou)
	Economia.recurso_mudou.connect(func(_r, _v): _atualizar())
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

	if e.em_obra:
		_label.text = "%s\n(obra)" % e.nome
		return

	var custo := Vila.custo_proximo_nivel(edificio_id)
	var pode_pagar := Economia.tem_saldo("ouro", custo["ouro"]) and Economia.tem_saldo("madeira", custo["madeira"])
	var nivel_texto := "ruína" if e.nivel == 0 else "nv %d" % e.nivel
	_label.text = "%s\n(%s)\n%s %dg %dm" % [
		e.nome, nivel_texto, ("toque p/ nv %d:" % (e.nivel + 1)), custo["ouro"], custo["madeira"],
	]
	_label.modulate = Color.WHITE if pode_pagar else Color(1, 0.6, 0.6)


## Detecção manual de clique (não usa Area2D/picking de física — mais simples de
## garantir que funciona, e igual em desktop e mobile). Chamado pelo Mapa.
func contem_ponto_mundo(pt: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(pt), _silhueta.polygon)
