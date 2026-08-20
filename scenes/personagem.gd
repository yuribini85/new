extends Node2D
## Token de personagem (líder ou órfão) no mapa. Usa a arte real quando existe em
## res://art/chr/twb_chr_<slug>_idle.png (docs/NOMENCLATURA_ASSETS.md) — hoje
## "aldeao" (adulto, qualquer papel) e "crianca"; cai no losango placeholder pra
## qualquer papel sem arte ainda. A "caminhada" é procedural (Godot Tween — balanço
## mais rápido e um leve esticão vertical), sem nenhum quadro de animação novo: o
## Mapa chama definir_andando(true) enquanto desloca esse token entre prédios pela
## rua, e definir_andando(false) quando ele chega e volta a ficar parado.

const ART_DIR := "res://art/chr/"
const ALTURA_SPRITE := 56.0  # altura alvo na tela, em px de mundo

@onready var _visual: Node2D = $Visual
@onready var _corpo: Polygon2D = $Visual/Corpo
@onready var _sprite: Sprite2D = $Visual/Sprite

var _tween_balanco: Tween
var _andando := false


func configurar(cor: Color, crianca: bool = false) -> void:
	var slug := "crianca" if crianca else "aldeao"
	var caminho := "%stwb_chr_%s_idle.png" % [ART_DIR, slug]
	if ResourceLoader.exists(caminho):
		var textura: Texture2D = load(caminho)
		_sprite.texture = textura
		var escala: float = ALTURA_SPRITE / textura.get_height()
		_sprite.scale = Vector2.ONE * escala
		_sprite.position = Vector2(-textura.get_width() * escala / 2.0, -textura.get_height() * escala)
		_sprite.visible = true
		_corpo.visible = false
	else:
		_corpo.color = cor
		_corpo.visible = true
		_sprite.visible = false
	definir_andando(false)


func definir_andando(andando: bool) -> void:
	if _andando == andando and _tween_balanco != null:
		return
	_andando = andando
	if _tween_balanco != null:
		_tween_balanco.kill()

	_tween_balanco = create_tween().set_loops()
	if andando:
		# Passo: balanço rápido + esticão vertical (squash/stretch) — sem sprite de
		# perna nenhum, só a leitura de "passo" que o Tween consegue sozinho.
		_tween_balanco.tween_property(_visual, "position:y", -4.0, 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.parallel().tween_property(_visual, "scale", Vector2(0.85, 1.15), 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.chain().tween_property(_visual, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.parallel().tween_property(_visual, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	else:
		var atraso := randf() * 0.6  # dessincroniza o balanço entre personagens parados
		_tween_balanco.tween_interval(atraso)
		_tween_balanco.tween_property(_visual, "position:y", -3.0, 0.7).set_trans(Tween.TRANS_SINE)
		_tween_balanco.tween_property(_visual, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
