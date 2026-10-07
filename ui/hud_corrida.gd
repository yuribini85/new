class_name HudCorrida
extends Control
## Painel da corrida sobre a pista, com os dados do HUD do GT2 (posição,
## volta, tempo da volta, melhor volta, velocidade, marcha e conta-giros) num
## desenho calmo: tipografia limpa, linhas finas, sem caixas; o âmbar marca o
## que é seu e o vermelho só a faixa de corte do motor.

const COR := Color(0.93, 0.92, 0.88)
const SUAVE := Color(0.93, 0.92, 0.88, 0.62)
const AMBAR := Color(0.95, 0.71, 0.19)
const CORTE := Color(0.95, 0.36, 0.28)
const SOMBRA := Color(0, 0, 0, 0.55)

var _d := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## d: posicao, total, volta, voltas, tempo_volta, melhor (s ou -1), kmh, marcha,
## giro, corte, giro_max.
func definir(d: Dictionary) -> void:
	_d = d
	queue_redraw()


func _texto(t: String, pos: Vector2, tam: int, cor: Color, alinhar := HORIZONTAL_ALIGNMENT_LEFT, largura := -1.0) -> void:
	var f := get_theme_default_font()
	draw_string_outline(f, pos, t, alinhar, largura, tam, 6, SOMBRA)
	draw_string(f, pos, t, alinhar, largura, tam, cor)


func _draw() -> void:
	if _d.is_empty():
		return
	var f := get_theme_default_font()
	var x := 18.0
	# Posição: o número grande, o total pequeno ao lado.
	var pos := str(_d["posicao"])
	var cor_pos := AMBAR if int(_d["posicao"]) == 1 else COR
	_texto(pos, Vector2(x, 78), 76, cor_pos)
	var w := f.get_string_size(pos, HORIZONTAL_ALIGNMENT_LEFT, -1, 76).x
	_texto("/%d" % _d["total"], Vector2(x + w + 4, 78), 30, SUAVE)
	# Linha fina e a volta.
	draw_line(Vector2(x, 92), Vector2(x + 190, 92), Color(COR, 0.35), 2.0)
	_texto("VOLTA  %d/%d" % [_d["volta"], _d["voltas"]], Vector2(x, 124), 24, COR)
	_texto(_tempo(float(_d["tempo_volta"])), Vector2(x, 156), 28, COR)
	if float(_d.get("melhor", -1.0)) > 0.0:
		_texto("melhor  " + _tempo(float(_d["melhor"])), Vector2(x, 184), 22, SUAVE)
	# Embaixo à esquerda: velocidade e marcha.
	var base_y := size.y - 70.0
	var kmh := "%d" % roundi(float(_d["kmh"]))
	_texto(kmh, Vector2(x, base_y), 64, COR)
	var wk := f.get_string_size(kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	_texto("km/h", Vector2(x + wk + 6, base_y), 22, SUAVE)
	if int(_d.get("marcha", 0)) > 0:
		var gx := x + wk + 70.0
		draw_line(Vector2(gx, base_y - 50), Vector2(gx, base_y + 4), Color(COR, 0.35), 2.0)
		_texto(str(_d["marcha"]), Vector2(gx + 14, base_y), 56, AMBAR)
		_texto("marcha", Vector2(gx + 14, base_y + 24), 18, SUAVE)
	# Conta-giros: uma linha fina com marcas a cada 1000 rpm; o trecho até o
	# giro atual em âmbar; depois do corte, vermelho.
	var giro_max := float(_d.get("giro_max", 0.0))
	if giro_max > 0.0:
		var x0 := x
		var x1 := size.x - 18.0
		var y := size.y - 20.0
		var ax := func(g: float) -> float: return lerpf(x0, x1, clampf(g / giro_max, 0.0, 1.0))
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(COR, 0.25), 2.0)
		var corte := float(_d["corte"])
		draw_line(Vector2(ax.call(corte), y), Vector2(x1, y), Color(CORTE, 0.6), 2.0)
		var g := 0.0
		while g <= giro_max:
			var tx: float = ax.call(g)
			draw_line(Vector2(tx, y - (10.0 if int(g) % 2000 == 0 else 6.0)), Vector2(tx, y), Color(COR, 0.45), 2.0)
			g += 1000.0
		var giro := float(_d["giro"])
		draw_line(Vector2(x0, y), Vector2(ax.call(giro), y), CORTE if giro >= corte - 150.0 else AMBAR, 5.0)
		var rotulo := "×1000 rpm"
		_texto(rotulo, Vector2(x1 - f.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x, y - 14), 16, SUAVE)


static func _tempo(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(maxf(t, 0.0), 60.0)]
