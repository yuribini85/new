class_name HudCorrida
extends Control
## Painel da corrida sobre a pista, com os dados do HUD do GT2 num desenho
## calmo: tipografia limpa, linhas finas, sem caixas.
##
## Hierarquia (o que se vê primeiro): posição; acontecimento da corrida (texto
## de evento no centro, entra e sai); volta; diferença para os rivais (na
## classificação). Velocidade, marcha e giro ficam em segundo plano, menores e
## apagados. O âmbar só marca a posição do jogador e o que é importante.
##
## `secundario` (0..1) apaga o que é secundário quando a corrida pede foco
## (disputa, chegada); a mudança é gradual.

signal escolhido(id: String)

const COR := Color(0.93, 0.92, 0.88)
const SUAVE := Color(0.93, 0.92, 0.88, 0.6)
const APAGADO := Color(0.93, 0.92, 0.88, 0.42)
const AMBAR := Aba.COR_DESTAQUE  # ocre, o mesmo do menu
const CORTE := Color(0.95, 0.36, 0.28)
const SOMBRA := Color(0, 0, 0, 0.6)
## Classificação: canto superior direito, abaixo do minimapa.
const LISTA_TOPO := 184.0
const LISTA_LARGURA := 250.0
const LISTA_LINHA := 30.0
## Evento: entra subindo um pouco, fica e sai devagar.
const EVENTO_ENTRA_S := 0.4
const EVENTO_SAI_S := 0.7
const EVENTO_FICA_S := 2.2
const EVENTO_PENDENTE_MAX_S := 3.0
## Poucos eventos com peso: os de prioridade até INTERVALO_PRIO só aparecem
## INTERVALO_S depois do último evento.
const INTERVALO_S := 6.0
const INTERVALO_PRIO := 3

var _d := {}
## Alvo de opacidade do que é secundário; _sec segue devagar.
var secundario := 1.0
var _sec := 1.0
var _evento := {}  # {"titulo", "sub", "cor", "prio", "t", "fica", "grande"}
var _pendente := {}
var _ultimo := -INF  # quando o último evento apareceu (s, relógio do sistema)


func _init() -> void:
	# Só a classificação recebe toque (ver _has_point); o resto passa adiante.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## d: posicao, total, volta, voltas, tempo_volta, melhor (s ou -1), kmh, marcha,
## giro, corte, giro_max; lista: [{id, nome, cor, voce, camera, gap, ataque}] em
## ordem (gap: s atrás do líder; ataque: está atacando o jogador).
func definir(d: Dictionary) -> void:
	_d = d
	queue_redraw()


## Acontecimento da corrida: título e linha de baixo, no centro. Um por vez:
## prioridade maior substitui; menor espera a vez (e expira se demorar).
## `fica_s` < 0: até limpar_evento() (a chegada).
func evento(titulo: String, sub := "", cor := COR, prio := 1, fica_s := EVENTO_FICA_S, grande := false) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	var e := {"titulo": titulo, "sub": sub, "cor": cor, "prio": prio, "t": 0.0, "fica": fica_s, "grande": grande,
			"pedido": agora}
	# O mesmo acontecimento de novo (três ultrapassagens seguidas): atualiza a
	# linha de baixo e prolonga, sem piscar.
	if not _evento.is_empty() and _evento["titulo"] == titulo:
		_evento["sub"] = sub
		_evento["t"] = minf(float(_evento["t"]), EVENTO_ENTRA_S)
		set_process(true)
		return
	if prio <= INTERVALO_PRIO and agora - _ultimo < INTERVALO_S:
		return
	if _evento.is_empty() or prio > int(_evento["prio"]):
		_evento = e
		_ultimo = agora
	elif _pendente.is_empty() or prio >= int(_pendente["prio"]):
		_pendente = e
	set_process(true)


func limpar_evento() -> void:
	_evento = {}
	_pendente = {}
	queue_redraw()


func ocupado() -> bool:
	return not _evento.is_empty()


func _process(delta: float) -> void:
	var antes := _sec
	_sec = move_toward(_sec, secundario, delta / 0.6)
	if not _evento.is_empty():
		_evento["t"] = float(_evento["t"]) + delta
		var fica := float(_evento["fica"])
		if fica >= 0.0 and float(_evento["t"]) > EVENTO_ENTRA_S + fica + EVENTO_SAI_S:
			_evento = {}
	if _evento.is_empty() and not _pendente.is_empty():
		if Time.get_ticks_msec() / 1000.0 - float(_pendente["pedido"]) < EVENTO_PENDENTE_MAX_S:
			_evento = _pendente
			_ultimo = Time.get_ticks_msec() / 1000.0
		_pendente = {}
	if _evento.is_empty() and is_equal_approx(antes, _sec) and _sec == secundario:
		set_process(false)
	queue_redraw()


func _texto(t: String, pos: Vector2, tam: int, cor: Color, alinhar := HORIZONTAL_ALIGNMENT_LEFT, largura := -1.0) -> void:
	var f := get_theme_default_font()
	draw_string_outline(f, pos, t, alinhar, largura, tam, 6, Color(SOMBRA, SOMBRA.a * cor.a))
	draw_string(f, pos, t, alinhar, largura, tam, cor)


static func _a(c: Color, a: float) -> Color:
	return Color(c, c.a * a)


func _draw() -> void:
	if _d.is_empty():
		return
	var f := get_theme_default_font()
	var x := 18.0
	# 1. Posição: o número grande em âmbar (é o seu), o total pequeno ao lado.
	var pos := str(_d["posicao"])
	_texto(pos, Vector2(x, 82), 80, AMBAR)
	var w := f.get_string_size(pos, HORIZONTAL_ALIGNMENT_LEFT, -1, 80).x
	_texto("/%d" % _d["total"], Vector2(x + w + 4, 82), 28, SUAVE)
	# 3. Volta; o tempo da volta e a melhor, menores (secundários).
	_texto("VOLTA  %d/%d" % [_d["volta"], _d["voltas"]], Vector2(x, 120), 26, COR)
	_texto(_tempo(float(_d["tempo_volta"])), Vector2(x, 150), 22, _a(SUAVE, _sec))
	if float(_d.get("melhor", -1.0)) > 0.0:
		_texto("melhor " + _tempo(float(_d["melhor"])), Vector2(x, 176), 20, _a(APAGADO, _sec))
	_lista()
	_motor()
	_desenhar_evento()


## Velocidade, marcha e giro: embaixo à esquerda, pequenos e apagados.
func _motor() -> void:
	var f := get_theme_default_font()
	var x := 18.0
	var base_y := size.y - 34.0
	var cor := _a(SUAVE, _sec)
	var kmh := "%d" % roundi(float(_d["kmh"]))
	_texto(kmh, Vector2(x, base_y), 40, cor)
	var wk := f.get_string_size(kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	_texto("km/h", Vector2(x + wk + 5, base_y), 18, _a(APAGADO, _sec))
	var gx := x + wk + 62.0
	if int(_d.get("marcha", 0)) > 0:
		_texto(str(_d["marcha"]), Vector2(gx, base_y), 34, cor)
		_texto("ª", Vector2(gx + f.get_string_size(str(_d["marcha"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x + 1, base_y - 14),
				16, _a(APAGADO, _sec))
	# Giro: linha curta e fina sob os números; a faixa de corte só insinuada.
	var giro_max := float(_d.get("giro_max", 0.0))
	if giro_max <= 0.0:
		return
	var x0 := x
	var x1 := x + 230.0
	var y := size.y - 18.0
	var ax := func(g: float) -> float: return lerpf(x0, x1, clampf(g / giro_max, 0.0, 1.0))
	var corte := float(_d["corte"])
	draw_line(Vector2(x0, y), Vector2(x1, y), _a(Color(COR, 0.18), _sec), 1.0)
	draw_line(Vector2(ax.call(corte), y), Vector2(x1, y), _a(Color(CORTE, 0.35), _sec), 1.0)
	var giro := float(_d["giro"])
	var no_corte := giro >= corte - 150.0
	draw_line(Vector2(x0, y), Vector2(ax.call(giro), y), _a(Color(CORTE, 0.7) if no_corte else Color(COR, 0.5), _sec), 2.0)


## Evento no centro: texto direto sobre a cena, com uma faixa escura muito leve
## só para garantir a leitura. Entra subindo 10 px, sai devagar.
func _desenhar_evento() -> void:
	if _evento.is_empty():
		return
	var t := float(_evento["t"])
	var fica := float(_evento["fica"])
	var a := smoothstep(0.0, EVENTO_ENTRA_S, t)
	if fica >= 0.0:
		a *= 1.0 - smoothstep(EVENTO_ENTRA_S + fica, EVENTO_ENTRA_S + fica + EVENTO_SAI_S, t)
	if a <= 0.0:
		return
	var grande: bool = _evento["grande"]
	var cy := size.y * (0.5 if grande else 0.68) + (1.0 - smoothstep(0.0, EVENTO_ENTRA_S, t)) * 10.0
	var tam_t := 30 if grande else 36
	var tam_s := 110 if grande else 26
	# Faixa: escura no meio, transparente nas pontas.
	var alt := 150.0 if grande else 96.0
	var y0 := cy - alt * 0.62
	var meio := Color(0, 0, 0, 0.26 * a)
	var nada := Color(0, 0, 0, 0)
	var xs := [0.0, size.x * 0.25, size.x * 0.75, size.x]
	for i in 3:
		var c0: Color = nada if i == 0 else meio
		var c1: Color = nada if i == 2 else meio
		draw_polygon(PackedVector2Array([Vector2(xs[i], y0), Vector2(xs[i + 1], y0), Vector2(xs[i + 1], y0 + alt),
				Vector2(xs[i], y0 + alt)]), PackedColorArray([c0, c1, c1, c0]))
	var cor: Color = _evento["cor"]
	if grande:
		# Chegada: a linha pequena em cima, a posição enorme embaixo.
		_texto(String(_evento["titulo"]), Vector2(0, cy - 44), tam_t, Color(COR, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_texto(String(_evento["sub"]), Vector2(0, cy + 52), tam_s, Color(cor, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
	_texto(String(_evento["titulo"]), Vector2(0, cy), tam_t, Color(cor, a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if String(_evento["sub"]) != "":
		_texto(String(_evento["sub"]), Vector2(0, cy + 34), tam_s, Color(COR, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _lista_rect() -> Rect2:
	var n: int = _d.get("lista", []).size()
	return Rect2(size.x - LISTA_LARGURA - 16.0, LISTA_TOPO, LISTA_LARGURA + 16.0, n * LISTA_LINHA + 8.0)


func _has_point(p: Vector2) -> bool:
	return _lista_rect().has_point(p)


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if not toque:
		return
	var i := floori((e.position.y - LISTA_TOPO) / LISTA_LINHA)
	var lista: Array = _d.get("lista", [])
	if i >= 0 and i < lista.size():
		escolhido.emit(String(lista[i]["id"]))
		accept_event()


## Classificação: posição, cor do carro, nome e diferença para o líder. Só a
## linha relevante fica clara: a sua (número em âmbar) e, por um momento, a de
## quem está atacando você; as outras ficam neutras. Uma linha fina à esquerda
## marca o carro que a câmera segue.
func _lista() -> void:
	var lista: Array = _d.get("lista", [])
	var f := get_theme_default_font()
	var x0 := size.x - LISTA_LARGURA
	for i in lista.size():
		var it: Dictionary = lista[i]
		var y := LISTA_TOPO + (i + 1) * LISTA_LINHA - 6.0
		var voce: bool = it.get("voce", false)
		var ataque: bool = it.get("ataque", false)
		var forca := 1.0 if voce or ataque else lerpf(0.25, 0.55, _sec)
		var cor := Color(COR, forca)
		if it.get("camera", false):
			draw_line(Vector2(x0 - 10.0, y - 20.0), Vector2(x0 - 10.0, y + 4.0), Color(COR, 0.6 * forca), 2.0)
		_texto("%d" % (i + 1), Vector2(x0, y), 22, AMBAR if voce else cor, HORIZONTAL_ALIGNMENT_RIGHT, 24.0)
		draw_rect(Rect2(x0 + 32.0, y - 14.0, 10.0, 10.0), Color(it["cor"], forca))
		var gap := float(it.get("gap", -1.0))
		var gap_txt := "" if gap < 0.0 else ("+%.1f" % gap if gap < 60.0 else "+1 v")
		var wg := f.get_string_size(gap_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x if gap_txt != "" else 0.0
		var nome: String = it["nome"]
		var max_l := LISTA_LARGURA - 52.0 - wg - 10.0
		if f.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > max_l:
			while nome.length() > 3 and f.get_string_size(nome + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x > max_l:
				nome = nome.left(-1)
			nome += "…"
		_texto(nome, Vector2(x0 + 52.0, y), 22, cor)
		if gap_txt != "":
			_texto(gap_txt, Vector2(x0, y), 20, Color(CORTE, 0.95) if ataque else Color(COR, forca * 0.8),
					HORIZONTAL_ALIGNMENT_RIGHT, LISTA_LARGURA)


static func _tempo(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(maxf(t, 0.0), 60.0)]
