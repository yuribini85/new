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
const LISTA_LINHA := 44.0  # nome do piloto e, embaixo, a equipe
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
## Vista DADOS: só os acontecimentos da corrida (o resto está na vista tática).
var so_eventos := false
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


func _texto(t: String, pos: Vector2, tam: int, cor: Color, alinhar := HORIZONTAL_ALIGNMENT_LEFT, largura := -1.0,
		f: Font = null) -> void:
	if f == null:
		f = get_theme_default_font()
	draw_string_outline(f, pos, t, alinhar, largura, tam, 6, Color(SOMBRA, SOMBRA.a * cor.a))
	draw_string(f, pos, t, alinhar, largura, tam, cor)


static func _a(c: Color, a: float) -> Color:
	return Color(c, c.a * a)


func _draw() -> void:
	if so_eventos:
		_desenhar_evento()
		return
	if _d.is_empty():
		return
	var f := Tipografia.fonte_numero()
	var x := 18.0
	# 1. Posição: o número grande em âmbar (é o seu), o total pequeno ao lado.
	var pos := str(_d["posicao"])
	_texto(pos, Vector2(x, 82), 80, AMBAR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	var w := f.get_string_size(pos, HORIZONTAL_ALIGNMENT_LEFT, -1, 80).x
	_texto("/%d" % _d["total"], Vector2(x + w + 4, 82), 28, SUAVE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	# 3. Volta (o tempo dela fica no cronômetro, embaixo).
	_texto("VOLTA  %d/%d" % [_d["volta"], _d["voltas"]], Vector2(x, 120), 26, COR)
	_lista()
	_conta_giros()
	_cronometro()
	_desenhar_evento()


## Instrumentos analógicos, minimalistas: arcos finos concêntricos, sem escala
## nem números no mostrador; o ponteiro é uma linha fina com uma cápsula curta
## em ocre junto ao eixo. Só o que a simulação calcula: giro, marcha e
## velocidade no conta-giros; tempo da volta e diferença para a melhor volta no
## cronômetro. Ficam no plano secundário: apagam com `_sec` na disputa e na
## chegada.

const GIRO_RAIO := 96.0
const GIRO_ARCO := 135.0  # graus: da esquerda do eixo (180°) ao alto-direita (315°)
const CRONO_RAIO := 52.0
const CRONO_FENDA := 70.0  # graus abertos à direita (o "C")
const ARCOS := 5  # linhas concêntricas
const ARCO_PASSO := 4.0
## Na disputa os instrumentos apagam, mas não somem (traço fino some antes do texto).
const INST_MIN := 0.55


func _alfa_inst() -> float:
	return lerpf(INST_MIN, 1.0, _sec)


func _centro_giro() -> Vector2:
	return Vector2(22.0 + GIRO_RAIO, size.y - 30.0)


func _txt_inst(t: String, pos: Vector2, tam: int, cor: Color, peso := "semibold", alinhar := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := Tipografia.fonte(peso)
	if alinhar == HORIZONTAL_ALIGNMENT_CENTER:
		pos.x -= f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x / 2.0
	draw_string_outline(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 5, Color(SOMBRA, SOMBRA.a * cor.a))
	draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


## Arcos concêntricos de `de` a `ate` (rad), o de fora mais claro e grosso, e a
## linha reta que fecha o fim do arco em direção ao eixo.
func _arcos(c: Vector2, raio: float, de: float, ate: float, a: float, fecha := true) -> void:
	for k in ARCOS:
		var r := raio - k * ARCO_PASSO
		draw_arc(c, r, de, ate, 64, _a(Color(COR, 0.62 - k * 0.09), a), 2.0 if k == 0 else 1.0, true)
	if fecha:
		var dir := Vector2(cos(ate), sin(ate))
		draw_line(c + dir * (raio * 0.12), c + dir * raio, _a(Color(COR, 0.5), a), 1.5, true)


## Ponteiro: linha fina cinza para fora e cápsula curta colorida junto ao eixo.
func _ponteiro(c: Vector2, raio: float, ang: float, cor: Color, a: float) -> void:
	var dir := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-dir.y, dir.x) * 3.0  # a linha corre ao lado da cápsula, como na referência
	draw_line(c + dir * (raio * 0.2) + lado, c + dir * (raio * 0.72) + lado, _a(Color(COR, 0.35), a), 2.0, true)
	draw_line(c + dir * (raio * 0.04), c + dir * (raio * 0.16), _a(cor, a), 6.0, true)


## Conta-giros: arco até o giro máximo da escala; perto do corte o ponteiro
## fica vermelho (hora de trocar). Marcha grande e velocidade ao lado do eixo.
func _conta_giros() -> void:
	var a := _alfa_inst()
	var c := _centro_giro()
	var giro_max := float(_d.get("giro_max", 0.0))
	var de := PI
	var ate := de + deg_to_rad(GIRO_ARCO)
	_arcos(c, GIRO_RAIO, de, ate, a)
	if giro_max > 0.0:
		var corte := float(_d["corte"])
		var giro := float(_d["giro"])
		# Só o trecho do corte no arco de fora, em vermelho discreto.
		draw_arc(c, GIRO_RAIO, lerpf(de, ate, corte / giro_max), ate, 16, _a(Color(CORTE, 0.8), a), 2.0, true)
		var cor := Color(CORTE) if giro >= corte - 400.0 else AMBAR
		_ponteiro(c, GIRO_RAIO, lerpf(de, ate, clampf(giro / giro_max, 0.0, 1.0)), cor, a)
	var marcha := int(_d.get("marcha", 0))
	_txt_inst(str(marcha) if marcha > 0 else "N", c + Vector2(GIRO_RAIO * 0.42, -GIRO_RAIO * 0.12), 40, _a(COR, a), "numero")
	_txt_inst("%d km/h" % roundi(float(_d["kmh"])), c + Vector2(GIRO_RAIO * 0.42 + 30.0, -GIRO_RAIO * 0.12), 22,
			_a(SUAVE, a), "medium")


## Cronômetro em "C": o ponteiro dá uma volta por minuto. Ao lado, o tempo da
## volta e a diferença para a melhor volta no mesmo ponto (ocre adiantado,
## vermelho atrasado).
func _cronometro() -> void:
	var a := _alfa_inst()
	var c := _centro_giro() + Vector2(GIRO_RAIO * 0.42 + 150.0 + CRONO_RAIO, -CRONO_RAIO + 8.0)
	var fenda := deg_to_rad(CRONO_FENDA) / 2.0
	_arcos(c, CRONO_RAIO, fenda, TAU - fenda, a, false)
	var t := float(_d.get("tempo_volta", 0.0))
	_ponteiro(c, CRONO_RAIO, -PI / 2.0 + TAU * fmod(t, 60.0) / 60.0, AMBAR, a)
	var x := c.x + CRONO_RAIO + 14.0
	_txt_inst(_tempo(t), Vector2(x, c.y + 2.0), 26, _a(SUAVE, a), "numero")
	var delta := float(_d.get("delta", INF))
	if delta != INF:
		_txt_inst("%+.2f" % delta, Vector2(x, c.y - 26.0), 22, _a(Color(CORTE) if delta > 0.0 else AMBAR, a))
	var melhor := float(_d.get("melhor", -1.0))
	if melhor > 0.0:
		_txt_inst("melhor " + _tempo(melhor), Vector2(x, c.y + 28.0), 18, _a(APAGADO, a), "regular")


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
	if so_eventos and not grande:
		# Vista DADOS: o aviso ocupa, por um momento, o bloco da próxima curva
		# (VistaDados, de 312 a 422), com fundo opaco, sem cobrir os números.
		draw_rect(Rect2(0, 314, size.x, 106), Color(VistaDados.FUNDO, a))
		cy = 368.0 + (1.0 - smoothstep(0.0, EVENTO_ENTRA_S, t)) * 10.0
		_texto(String(_evento["titulo"]), Vector2(0, cy), 36, Color(_evento["cor"], a), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if String(_evento["sub"]) != "":
			_texto(String(_evento["sub"]), Vector2(0, cy + 34), 26, Color(COR, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
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
	if so_eventos:
		return false
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
		var y := LISTA_TOPO + i * LISTA_LINHA + 24.0  # linha do nome; a equipe vai embaixo
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
		var equipe: String = it.get("equipe", "")
		if equipe != "":
			var eq_l := LISTA_LARGURA - 52.0
			if f.get_string_size(equipe, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > eq_l:
				while equipe.length() > 3 and f.get_string_size(equipe + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x > eq_l:
					equipe = equipe.left(-1)
				equipe += "…"
			_texto(equipe, Vector2(x0 + 52.0, y + 18.0), 16, Color(COR, forca * 0.6))
		if gap_txt != "":
			_texto(gap_txt, Vector2(x0, y), 20, Color(CORTE, 0.95) if ataque else Color(COR, forca * 0.8),
					HORIZONTAL_ALIGNMENT_RIGHT, LISTA_LARGURA)


static func _tempo(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(maxf(t, 0.0), 60.0)]
