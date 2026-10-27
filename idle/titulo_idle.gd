class_name TituloIdle
extends Control
## Tela de título do Chrome Racing Team (docs/idle/conversao_mafia.md): uma rua de
## Nova York em 1948, com o cartaz da corrida clandestina e o carro de época, o
## logotipo e "TOQUE PARA COMEÇAR". Aparece ao abrir o app; um toque fecha.

signal fechou

## Apresentação, não balanceamento.
const SAIDA_S := 0.35
const CEU_ALTO := Color("10141c")
const CEU_BAIXO := Color("2a2a30")
const TIJOLO := Color("4a2a20")
const LUZ := Color("f3d27a")

var _toque: Label
var _t := 0.0
var _saindo := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var logo := TextureRect.new()
	logo.texture = load("res://arte/idle/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	logo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	logo.offset_left = 30
	logo.offset_right = -30
	logo.offset_top = -470
	logo.offset_bottom = -210
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	_toque = IdleUI.rotulo("TOQUE PARA COMEÇAR", 26, IdleUI.COR_CROMO)
	_toque.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toque.offset_top = -170
	_toque.offset_bottom = -110
	_toque.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toque)


func _process(delta: float) -> void:
	_t += delta
	_toque.modulate.a = 0.55 + 0.45 * absf(sin(_t * 1.6))
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if toque:
		accept_event()
		fechar()


func fechar() -> void:
	if _saindo:
		return
	_saindo = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sons.tocar_ui(self, "toque", -6.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.0 if Preferencias.reduzir_animacoes else SAIDA_S)
	tw.tween_callback(func():
		fechou.emit()
		queue_free())


func _draw() -> void:
	var chao := size.y * 0.58
	TituloIdle.rua(self, size.x, size.y, _t, chao)
	TituloIdle.carro_antigo(self, Vector2(size.x * 0.08, chao + 90), Color("8e2a26"), 330.0)


## Rua de Nova York em 1948 (título e abertura): céu em faixas, prédios de
## tijolo com janelas acesas, poste de luz e o cartaz da corrida clandestina.
static func rua(ci: CanvasItem, w: float, h: float, t: float, chao: float) -> void:
	for k in 6:
		ci.draw_rect(Rect2(0, chao * k / 6.0, w, chao / 6.0 + 1), CEU_ALTO.lerp(CEU_BAIXO, k / 5.0))
	# Prédios de tijolo, em planos, com janelas.
	var predios := [[0.0, 0.34, 0.3], [0.3, 0.22, 0.26], [0.56, 0.3, 0.22], [0.78, 0.22, 0.12]]
	for p in predios:
		var x := w * float(p[0])
		var largura := w * float(p[2])
		var topo := chao * float(p[1])
		ci.draw_rect(Rect2(x, topo, largura, chao - topo), TIJOLO.darkened(0.15 * (int(p[0] * 10) % 3)))
		ci.draw_rect(Rect2(x, topo, largura, 10), TIJOLO.lightened(0.15))
		var y := topo + 40.0
		var linha := 0
		while y < chao - 60.0:
			var jx := x + 22.0
			var coluna := 0
			while jx < x + largura - 40.0:
				var acesa := (linha * 7 + coluna * 3 + int(p[0] * 13)) % 5 == 0
				ci.draw_rect(Rect2(jx, y, 26, 36), Color("e9c46a", 0.85) if acesa else Color("0d0b09"))
				jx += 52.0
				coluna += 1
			y += 70.0
			linha += 1
	# Cartaz da corrida, colado no prédio do meio.
	var o := Vector2(w * 0.36, chao * 0.48)
	ci.draw_rect(Rect2(o, Vector2(w * 0.5, 150)), Color("eadfc4"))
	ci.draw_rect(Rect2(o + Vector2(8, 8), Vector2(w * 0.5 - 16, 134)), Color("8e2a26"), false, 4.0)
	var fonte := Tipografia.fonte("display")
	ci.draw_string(fonte, o + Vector2(22, 56), "GRANDE CORRIDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("8e2a26"))
	ci.draw_string(fonte, o + Vector2(22, 104), "SÁBADO · 1948", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("15120e"))
	ci.draw_string(fonte, o + Vector2(22, 136), "CAIS 17 · À MEIA-NOITE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("3a3226"))
	# Calçada, rua e o poste com a luz no chão.
	ci.draw_rect(Rect2(0, chao, w, 30), Color("2a2620"))
	ci.draw_rect(Rect2(0, chao + 30, w, h - chao - 30), Color("0e0d0b"))
	var px := w * 0.9
	ci.draw_rect(Rect2(px - 5, chao - 300, 10, 300), Color("15120e"))
	ci.draw_rect(Rect2(px - 30, chao - 312, 50, 14), Color("15120e"))
	var pulso := 0.9 + 0.1 * sin(t * 7.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 30, chao - 298), Vector2(px + 20, chao - 298),
			Vector2(px + 110, chao + 30), Vector2(px - 150, chao + 30)]), Color(LUZ, 0.10 * pulso))
	ci.draw_circle(Vector2(px - 5, chao - 296), 10, Color(LUZ, pulso))


## Carro de passeio dos anos 1940 em planos chapados, de perfil: para-lamas
## destacados e arredondados, cabine alta, estribo, grade vertical e faróis
## separados. Sem emblema de fabricante.
static func carro_antigo(ci: CanvasItem, pe: Vector2, cor: Color, a: float) -> void:
	var escuro := cor.darkened(0.35)
	# Para-lamas (arcos sobre as rodas).
	for x in [a * 0.2, a * 0.8]:
		ci.draw_circle(pe + Vector2(x, -18), a * 0.13, cor)
	# Corpo baixo e capô comprido.
	ci.draw_colored_polygon(PackedVector2Array([pe + Vector2(a * 0.02, -16), pe + Vector2(a * 0.04, -54),
			pe + Vector2(a * 0.32, -62), pe + Vector2(a * 0.98, -56), pe + Vector2(a, -20), pe + Vector2(a * 0.96, -10),
			pe + Vector2(a * 0.04, -10)]), cor)
	# Cabine alta e arredondada.
	ci.draw_colored_polygon(PackedVector2Array([pe + Vector2(a * 0.12, -60), pe + Vector2(a * 0.2, -108),
			pe + Vector2(a * 0.3, -122), pe + Vector2(a * 0.52, -122), pe + Vector2(a * 0.62, -104), pe + Vector2(a * 0.66, -60)]), cor)
	ci.draw_colored_polygon(PackedVector2Array([pe + Vector2(a * 0.22, -66), pe + Vector2(a * 0.27, -106),
			pe + Vector2(a * 0.39, -112), pe + Vector2(a * 0.39, -66)]), Color(0.08, 0.1, 0.12, cor.a))
	ci.draw_colored_polygon(PackedVector2Array([pe + Vector2(a * 0.42, -66), pe + Vector2(a * 0.42, -112),
			pe + Vector2(a * 0.51, -112), pe + Vector2(a * 0.6, -66)]), Color(0.08, 0.1, 0.12, cor.a))
	# Estribo, grade e farol.
	ci.draw_rect(Rect2(pe + Vector2(a * 0.3, -14), Vector2(a * 0.42, 6)), escuro)
	ci.draw_rect(Rect2(pe + Vector2(a * 0.95, -54), Vector2(a * 0.04, 34)), Color("c8b07a", cor.a))
	ci.draw_circle(pe + Vector2(a * 0.9, -62), a * 0.03, Color("f3e3b0", cor.a))
	for x in [a * 0.2, a * 0.8]:
		ci.draw_circle(pe + Vector2(x, 0), a * 0.085, Color(0.06, 0.06, 0.06, cor.a))
		ci.draw_circle(pe + Vector2(x, 0), a * 0.045, Color("eadfc4", cor.a))
