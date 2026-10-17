class_name ChaveLiga
extends Button
## Chave liga/desliga desenhada: trilho arredondado (ocre quando ligada) e o
## botão redondo que corre de um lado ao outro. Área de toque do Button.

const TRILHO := Vector2(68, 36)
const COR_DESLIGADA := Color(0.24, 0.25, 0.28)
const COR_BOTAO := Color(0.9, 0.9, 0.88)

var _pos := 0.0  # 0 desligada → 1 ligada (animado)


func _init(ligada := false) -> void:
	toggle_mode = true
	button_pressed = ligada
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(TRILHO.x + 16, Tipografia.ALTURA_SECUNDARIA)
	_pos = 1.0 if ligada else 0.0
	toggled.connect(func(_x):
		var tw := create_tween()
		tw.tween_method(func(p): _pos = p; queue_redraw(), _pos, 1.0 if button_pressed else 0.0, 0.12))


func _draw() -> void:
	var r := Rect2((size - TRILHO) / 2.0, TRILHO)
	var cor := COR_DESLIGADA.lerp(Aba.COR_DESTAQUE, _pos)
	var raio := TRILHO.y / 2.0
	draw_circle(r.position + Vector2(raio, raio), raio, cor)
	draw_circle(r.position + Vector2(TRILHO.x - raio, raio), raio, cor)
	draw_rect(Rect2(r.position + Vector2(raio, 0), Vector2(TRILHO.x - 2.0 * raio, TRILHO.y)), cor)
	var cx := lerpf(r.position.x + raio, r.end.x - raio, _pos)
	draw_circle(Vector2(cx, r.position.y + raio), raio - 4.0, COR_BOTAO)
