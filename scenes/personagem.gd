extends Node2D
## Token placeholder de personagem (líder ou órfão) no mapa. Sem arte — quando os
## sprites de docs/NOMENCLATURA_ASSETS.md existirem, o Corpo vira um Sprite2D
## twb_chr_<slug>_idle.png. A "caminhada" é procedural (Godot Tween — balanço mais
## rápido e um leve esticão vertical), sem nenhum quadro de animação novo: o Mapa
## chama definir_andando(true) enquanto desloca esse token entre prédios pela rua,
## e definir_andando(false) quando ele chega e volta a ficar parado.

@onready var _corpo: Polygon2D = $Corpo

var _tween_balanco: Tween
var _andando := false


func configurar(cor: Color) -> void:
	_corpo.color = cor
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
		_tween_balanco.tween_property(_corpo, "position:y", -4.0, 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.parallel().tween_property(_corpo, "scale", Vector2(0.85, 1.15), 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.chain().tween_property(_corpo, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.parallel().tween_property(_corpo, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	else:
		var atraso := randf() * 0.6  # dessincroniza o balanço entre personagens parados
		_tween_balanco.tween_interval(atraso)
		_tween_balanco.tween_property(_corpo, "position:y", -3.0, 0.7).set_trans(Tween.TRANS_SINE)
		_tween_balanco.tween_property(_corpo, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
