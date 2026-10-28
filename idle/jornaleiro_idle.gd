class_name JornaleiroIdle
extends Control
## O menino jornaleiro (pedido do usuário, 2026-10-28): de vez em quando sobe de
## trás da faixa do prêmio, grita e acena com o jornal (12 quadros da arte do
## usuário em arte/fastfather/jornaleiro). O toque nele paga a gorjeta
## (IdleEstado.gorjeta_jornaleiro); se ninguém tocar, ele desce de novo.

signal tocado

## Apresentação, não balanceamento.
const QUADROS := 12
const QUADRO_S := 0.16
const ALTURA := 380.0  # o sprite inteiro na tela, do pé ao boné
const VISIVEL := 2.0 / 3.0  # do corpo dele, nunca mais que isto à mostra
const FOLGA_TOPO := 0.22  # o alto do quadro sem o menino (espaço do jornal erguido)
const SOBE_S := 0.35

var _quadros: Array[Texture2D] = []


## O caminho do quadro `i` (0 a QUADROS-1) da folha do menino.
static func quadro(i: int) -> String:
	return "res://arte/fastfather/jornaleiro/jornaleiro_%02d.png" % (i + 1)
var _imagem: TextureRect
var _t := 0.0
var _ate := 0.0
var _tw: Tween
var _ativo := false


func _init() -> void:
	for i in QUADROS:
		_quadros.append(load("res://arte/fastfather/jornaleiro/jornaleiro_%02d.png" % (i + 1)))
	var tam: Vector2 = _quadros[0].get_size()
	var inteiro := Vector2(tam.x * ALTURA / tam.y, ALTURA)
	custom_minimum_size = Vector2(inteiro.x, ALTURA * (FOLGA_TOPO + (1.0 - FOLGA_TOPO) * VISIVEL))
	size = custom_minimum_size
	clip_contents = true  # o terço de baixo nunca aparece
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagem = TextureRect.new()
	_imagem.texture = _quadros[0]
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT  # escala uniforme
	_imagem.size = inteiro
	_imagem.position = Vector2(0, size.y)
	_imagem.mouse_filter = Control.MOUSE_FILTER_STOP
	_imagem.gui_input.connect(_toque)
	add_child(_imagem)
	visible = false


func ativo() -> bool:
	return _ativo


## Sobe por `fica_s` segundos.
func aparecer(fica_s: float) -> void:
	if _ativo:
		return
	_ativo = true
	visible = true
	_t = 0.0
	_ate = fica_s
	_mover(0.0, null)
	Sons.tocar_ui(self, "voz", -10.0, 1.3)


func _mover(y: float, depois: Variant) -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_imagem, "position:y", y, SOBE_S).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT if y == 0.0 else Tween.EASE_IN)
	if depois is Callable:
		_tw.tween_callback(depois)


func esconder() -> void:
	if not _ativo:
		return
	_ativo = false
	_mover(size.y, func(): visible = false)


func _process(delta: float) -> void:
	if not _ativo:
		return
	_t += delta
	if not Preferencias.reduzir_animacoes:
		_imagem.texture = _quadros[int(_t / QUADRO_S) % QUADROS]
	if _t >= _ate:
		esconder()


func _toque(e: InputEvent) -> void:
	if not _ativo:
		return
	if (e is InputEventScreenTouch or e is InputEventMouseButton) and e.pressed:
		accept_event()
		tocado.emit()
		IdleUI.saltar(_imagem, 1.12)
		esconder()
