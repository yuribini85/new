class_name VistaDados
extends Control
## Vista tática da corrida (câmera DADOS): a mesma corrida resolvida, em números,
## sem 3D. De cima para baixo: pista; velocidade, marcha e giro; a próxima curva
## (onde frear, a que velocidade contorna); volta, melhor e delta; quem está à
## frente e atrás de você; o progresso da volta com todos os carros.
## Só lê o que a tela de corrida calcula (definir); não decide nada.

const COR := Color(0.93, 0.92, 0.88)
const SUAVE := Color(0.93, 0.92, 0.88, 0.62)
const APAGADO := Color(0.93, 0.92, 0.88, 0.4)
const LINHA := Color(1, 1, 1, 0.08)
const FUNDO := Color(0.07, 0.08, 0.09)
const CORTE := Color(0.95, 0.36, 0.28)
const M := 28.0  # margem lateral

var _d := {}


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func definir(d: Dictionary) -> void:
	_d = d
	queue_redraw()


func _t(t: String, pos: Vector2, tam: int, cor: Color, peso := "semibold", alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var f := Tipografia.fonte(peso)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	if alinhar == HORIZONTAL_ALIGNMENT_RIGHT:
		pos.x -= w
	elif alinhar == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x -= w / 2.0
	draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
	return w


func _divisor(y: float) -> void:
	draw_line(Vector2(M, y), Vector2(size.x - M, y), LINHA, 1.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FUNDO)
	if _d.is_empty():
		return
	var direita := size.x - M
	var destaque := Aba.COR_DESTAQUE
	# Pista e rótulo da vista.
	_t(String(_d.get("pista_nome", "")).to_upper(), Vector2(M, 44), 20, SUAVE, "medium")
	_t("DADOS SIMULADOS", Vector2(direita, 44), 20, APAGADO, "medium", HORIZONTAL_ALIGNMENT_RIGHT)
	# Velocidade grande; marcha à direita.
	_t("%d" % roundi(float(_d.get("kmh", 0.0))), Vector2(M - 6, 200), 160, COR, "numero")
	_t("KM/H", Vector2(M, 236), 20, SUAVE, "medium")
	_t("MARCHA", Vector2(direita, 100), 20, SUAVE, "medium", HORIZONTAL_ALIGNMENT_RIGHT)
	var marcha := int(_d.get("marcha", 0))
	_t(str(marcha) if marcha > 0 else "N", Vector2(direita, 200), 104, destaque, "numero", HORIZONTAL_ALIGNMENT_RIGHT)
	# Giro: barra fina; o trecho do corte marcado, a barra fica vermelha perto dele.
	var giro := float(_d.get("giro", 0.0))
	var giro_max := float(_d.get("giro_max", 0.0))
	var corte := float(_d.get("corte", 0.0))
	var w_rpm := _t("RPM", Vector2(M, 284), 20, SUAVE, "medium")
	w_rpm += _t(" %s" % Aba.dinheiro(roundi(giro)), Vector2(M + w_rpm, 284), 20, COR, "semibold")
	if giro_max > 0.0:
		var x0 := M + w_rpm + 18.0
		var largura := direita - x0
		var y := 277.0
		draw_rect(Rect2(x0, y, largura, 6), Color(1, 1, 1, 0.08))
		draw_rect(Rect2(x0 + largura * corte / giro_max, y, largura * (1.0 - corte / giro_max), 6), Color(CORTE, 0.35))
		var no_corte := giro >= corte - 400.0
		draw_rect(Rect2(x0, y, largura * clampf(giro / giro_max, 0.0, 1.0), 6), CORTE if no_corte else destaque)
	_divisor(312)
	# Próxima curva.
	var p: Dictionary = _d.get("proxima", {})
	if not p.is_empty():
		var seta := "↰" if p.get("sentido", "esquerda") == "esquerda" else "↱"
		_t(seta, Vector2(M, 384), 40, SUAVE, "regular")
		var x := M + 54.0
		match String(p["estado"]):
			"frear":
				_t("PRÓXIMA · %s" % String(p["nome"]).to_upper(), Vector2(x, 352), 20, SUAVE, "medium")
				var w := _t("FREAR EM ", Vector2(x, 396), 34, COR)
				w += _t("%d" % roundi(float(p["distancia"])), Vector2(x + w, 396), 34, destaque)
				_t(" M", Vector2(x + w, 396), 34, COR)
			"freando":
				_t(String(p["nome"]).to_upper(), Vector2(x, 352), 20, SUAVE, "medium")
				_t("FREANDO", Vector2(x, 396), 34, destaque)
			_:
				_t(String(p["nome"]).to_upper(), Vector2(x, 352), 20, SUAVE, "medium")
				_t("NA CURVA", Vector2(x, 396), 34, COR)
		_t("contorna a %d km/h" % roundi(float(p["v_kmh"])), Vector2(direita, 396), 22, SUAVE, "regular",
				HORIZONTAL_ALIGNMENT_RIGHT)
	_divisor(422)
	# Volta, melhor e delta.
	_t("VOLTA %d/%d" % [int(_d.get("volta", 1)), int(_d.get("voltas", 1))], Vector2(M, 458), 20, SUAVE, "medium")
	_t(HudCorrida._tempo(float(_d.get("tempo_volta", 0.0))), Vector2(M, 500), 34, COR, "numero")
	var melhor := float(_d.get("melhor", -1.0))
	_t("MELHOR", Vector2(size.x / 2.0, 458), 20, SUAVE, "medium", HORIZONTAL_ALIGNMENT_CENTER)
	_t(HudCorrida._tempo(melhor) if melhor > 0.0 else "—", Vector2(size.x / 2.0, 500), 34, SUAVE, "medium",
			HORIZONTAL_ALIGNMENT_CENTER)
	_t("DELTA", Vector2(direita, 458), 20, SUAVE, "medium", HORIZONTAL_ALIGNMENT_RIGHT)
	var delta := float(_d.get("delta", INF))
	if delta != INF:
		_t("%+.2f s" % delta, Vector2(direita, 500), 34, CORTE if delta > 0.0 else destaque, "semibold", HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_t("—", Vector2(direita, 500), 34, APAGADO, "medium", HORIZONTAL_ALIGNMENT_RIGHT)
	_divisor(524)
	# À frente, você, atrás.
	var y := 532.0
	for linha in _d.get("vizinhos", []):
		_vizinho(linha, y)
		y += 52.0
	# Progresso da volta: todos os carros numa linha.
	_progresso(size.y - 22.0)


## Uma linha da classificação próxima: {pos, nome, sub, voce}.
func _vizinho(l: Dictionary, y: float) -> void:
	var voce: bool = l.get("voce", false)
	var cor := Color(0.1, 0.1, 0.1) if voce else COR
	if voce:
		draw_rect(Rect2(M - 10, y, size.x - 2 * M + 20, 48), Aba.COR_DESTAQUE)
	_t("%02d" % int(l["pos"]), Vector2(M, y + 36), 30, cor if voce else SUAVE, "medium")
	_t(String(l["nome"]).to_upper(), Vector2(M + 62, y + 24), 22, cor)
	_t(String(l["sub"]).to_upper(), Vector2(M + 62, y + 43), 16, Color(cor, 0.75), "medium")


func _progresso(y: float) -> void:
	draw_line(Vector2(M, y), Vector2(size.x - M, y), Color(1, 1, 1, 0.15), 2.0)
	var voce := {}
	for c in _d.get("progresso", []):
		if c.get("voce", false):
			voce = c
			continue
		draw_circle(Vector2(lerpf(M, size.x - M, float(c["frac"])), y), 5.0, Color(c["cor"], 0.8))
	if not voce.is_empty():
		var x := lerpf(M, size.x - M, float(voce["frac"]))
		draw_circle(Vector2(x, y), 8.0, Aba.COR_DESTAQUE)
