extends Node2D
## Representação visual de um lote/edifício no mapa. Placeholder geométrico por
## padrão — CLAUDE.md proíbe gerar arte — mas quando existe um asset real em
## res://art/bld/twb_bld_<id>_t<NN>.png (docs/NOMENCLATURA_ASSETS.md), a Sprite
## substitui a Silhueta. Arte é opcional por prédio: os que não têm caem no losango.

const ART_DIR := "res://art/bld/"
const MAX_TIER_BUSCA := 10  # nenhum prédio da bíblia passa disso (mina vai até t07)

const COR_RUINA := Color(0.4, 0.36, 0.3)  # mais clara que o fundo (0.07-0.09) —
                                           # antes tinha pouco contraste e "sumia"
const COR_OBRA := Color(0.55, 0.47, 0.22)
const COR_PRONTO := Color(0.24, 0.42, 0.26)

@onready var _silhueta: Polygon2D = $Silhueta
@onready var _sprite: Sprite2D = $Sprite
@onready var _label: Label = $Label

var edificio_id: String
var _p11: Vector2  # canto sul do losango (footprint) — âncora do chão da arte
var _largura_diamante: float


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
	_p11 = p11
	_largura_diamante = p10.x - p01.x

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

	_atualizar_sprite(e.nivel)

	if e.em_obra:
		_label.text = "%s\n(obra)" % e.nome
		return

	if not e.disponivel:
		_label.text = "%s\n(em breve)" % e.nome
		_label.modulate = Color(0.7, 0.7, 0.7)
		return

	var custo := Vila.custo_proximo_nivel(edificio_id)
	var pode_pagar := Economia.tem_saldo("ouro", custo["ouro"]) and Economia.tem_saldo("madeira", custo["madeira"])
	var nivel_texto := "ruína" if e.nivel == 0 else "nv %d" % e.nivel
	_label.text = "%s\n(%s)\n%s %dg %dm" % [
		e.nome, nivel_texto, ("toque p/ nv %d:" % (e.nivel + 1)), custo["ouro"], custo["madeira"],
	]
	_label.modulate = Color.WHITE if pode_pagar else Color(1, 0.6, 0.6)


## Troca a Silhueta (losango) por Sprite2D quando existe arte real pra esse
## prédio/nível — nem todo prédio tem asset ainda, então cai no placeholder
## quando não encontra nada. A âncora é o canto sul (_p11) do losango: a base
## da imagem fica exatamente onde o chão do lote termina.
func _atualizar_sprite(nivel: int) -> void:
	var textura := _textura_para_nivel(nivel)
	if textura == null:
		_sprite.visible = false
		_silhueta.visible = true
		return

	_silhueta.visible = false
	_sprite.visible = true
	_sprite.texture = textura
	var escala: float = _largura_diamante / textura.get_width()
	_sprite.scale = Vector2.ONE * escala
	_sprite.position = _p11 - Vector2(textura.get_width() * escala / 2.0, textura.get_height() * escala)


## Maior estágio de arte disponível até `nivel` (ruína = t00). Sem asset nenhum
## pra esse id, retorna null e quem chamou cai no placeholder geométrico.
func _textura_para_nivel(nivel: int) -> Texture2D:
	var tier: int = clampi(nivel, 0, MAX_TIER_BUSCA)
	while tier >= 0:
		var caminho := "%stwb_bld_%s_t%02d.png" % [ART_DIR, edificio_id, tier]
		if ResourceLoader.exists(caminho):
			return load(caminho)
		tier -= 1
	return null


## Detecção manual de clique (não usa Area2D/picking de física — mais simples de
## garantir que funciona, e igual em desktop e mobile). Chamado pelo Mapa.
func contem_ponto_mundo(pt: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(pt), _silhueta.polygon)
