class_name Destaque
extends Control
## Destaque do tutorial (HIGHLIGHT_* das cenas): contorno pulsante em volta de
## um controle de uma aba, por cima de tudo (até do escurecido do diálogo), sem
## pegar toque. Segue o controle se a tela rolar; some depois de DURACAO_S ou
## quando o controle sai da árvore (a aba foi reconstruída).

## Apresentação, não balanceamento.
const DURACAO_S := 6.0
const MARGEM := 8.0
const ESPESSURA := 5.0

var _alvo: Control
var _t := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func mostrar(alvo: Control) -> void:
	_alvo = alvo
	_t = 0.0
	visible = true
	queue_redraw()


func ativo() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _t >= DURACAO_S or not is_instance_valid(_alvo) or not _alvo.is_inside_tree() or not _alvo.is_visible_in_tree():
		visible = false
		_alvo = null
	queue_redraw()


func _draw() -> void:
	if not visible or not is_instance_valid(_alvo):
		return
	var r := _alvo.get_global_rect().grow(MARGEM)
	r.position -= get_global_rect().position
	# Pulso: forte no começo, some no fim.
	var pulso := 0.55 + 0.45 * sin(_t * TAU * 1.2)
	var fim := 1.0 - smoothstep(DURACAO_S - 1.0, DURACAO_S, _t)
	var cor := Aba.COR_DESTAQUE
	cor.a = pulso * fim
	draw_rect(r, cor, false, ESPESSURA)
	var halo := Aba.COR_DESTAQUE
	halo.a = 0.25 * pulso * fim
	draw_rect(r.grow(ESPESSURA), halo, false, ESPESSURA * 2.0)
