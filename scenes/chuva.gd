class_name Chuva
extends Node2D
## Chuva desenhada à mão — sem textura (CLAUDE.md proíbe gerar arte, mesma lógica
## dos placeholders geométricos do resto do jogo). Cada gota é um traço curto
## (draw_line) caindo na diagonal, reciclado quando sai da área de tela; espaço de
## tela porque o nó pai (Mapa/ClimaLayer) é um CanvasLayer, não afetado por câmera.

const N_GOTAS := 90
const COMPRIMENTO := 26.0
const VELOCIDADE_MIN := 900.0
const VELOCIDADE_MAX := 1300.0
const LARGURA := 2.0
const COR := Color(0.75, 0.85, 1.0, 0.55)

var _direcao := Vector2(0.22, 1.0).normalized()
var _gotas: Array = []  # cada item: {pos: Vector2, vel: float}

var emitting := false:
	set(v):
		emitting = v
		visible = v
		queue_redraw()


func _ready() -> void:
	for i in range(N_GOTAS):
		_gotas.append({"pos": _posicao_aleatoria(-2000.0, 1920.0), "vel": randf_range(VELOCIDADE_MIN, VELOCIDADE_MAX)})


func _posicao_aleatoria(y_min: float, y_max: float) -> Vector2:
	return Vector2(randf_range(-60.0, 1140.0), randf_range(y_min, y_max))


func _process(delta: float) -> void:
	if not emitting:
		return
	for g in _gotas:
		g["pos"] += _direcao * g["vel"] * delta
		if g["pos"].y > 1960.0:
			g["pos"] = _posicao_aleatoria(-200.0, -20.0)
			g["vel"] = randf_range(VELOCIDADE_MIN, VELOCIDADE_MAX)
	queue_redraw()


func _draw() -> void:
	if not emitting:
		return
	for g in _gotas:
		var p1: Vector2 = g["pos"]
		var p2: Vector2 = p1 - _direcao * COMPRIMENTO
		draw_line(p1, p2, COR, LARGURA)
