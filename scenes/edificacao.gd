extends Node2D
## Nó genérico de edificação, configurado por dado (data/edificacoes.json) — nunca uma
## cena por construção (mesmo princípio do schema universal de upgrade da bíblia
## #17.5). Placeholder geométrico (losango + rótulo) até existir
## art/cenario/edificacoes/<id>_exterior.png aprovado (manual §23.1:
## "Edificacoes/<Nome>/exterior/", achatado aqui num único arquivo por enquanto —
## sem níveis de upgrade implementados ainda pra nenhuma construção).

const ART_DIR := "res://art/cenario/edificacoes/"
const ALTURA_REFERENCIA := 220.0  # bem maior que Quint (96) — construção, não pessoa

@onready var _marcador: Polygon2D = $Marcador
@onready var _label: Label = $Label
@onready var _sprite: Sprite2D = $Sprite

var id: String
var nome: String


func configurar(edificacao_id: String, nome_exibicao: String) -> void:
	id = edificacao_id
	nome = nome_exibicao
	_label.text = nome
	_carregar_arte_se_existir()


func _carregar_arte_se_existir() -> void:
	var caminho := "%s%s_exterior.png" % [ART_DIR, id]
	if not ResourceLoader.exists(caminho):
		_sprite.visible = false
		_marcador.visible = true
		return

	var textura: Texture2D = load(caminho)
	var usado := textura.get_image().get_used_rect()
	var escala: float = ALTURA_REFERENCIA / float(usado.size.y)
	_sprite.texture = textura
	_sprite.scale = Vector2.ONE * escala
	var centro_x := usado.position.x + usado.size.x / 2.0
	var pes_y := usado.position.y + usado.size.y
	_sprite.position = Vector2(-centro_x * escala, -pes_y * escala)
	_sprite.visible = true
	_marcador.visible = false
