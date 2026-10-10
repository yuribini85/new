class_name HudCorrida
extends Control
## Painel da corrida sobre a pista, com os dados do HUD do GT2 num desenho
## calmo: tipografia limpa, linhas finas, sem caixas.
##
## Quatro cantos, o centro livre para a corrida (como os jogos de corrida
## vistos de cima): em cima à esquerda, a posição e a classificação relativa
## (líder, à frente, você, atrás); em cima à direita, a volta e os tempos em
## faixas finas; embaixo à esquerda, o conta-giros (secundário); embaixo à
## direita, o minimapa (aba_corrida). Um número grande por grupo, o resto
## pequeno; faixas escuras translúcidas, sem moldura. O âmbar só marca o
## jogador e o que é importante. Acontecimentos no centro, entram e saem.
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
## O HUD começa logo abaixo do cabeçalho; os cantos descem Y0 para a volta
## (à direita) não ficar sob o marcador da aceleração pendurado nele.
const Y0 := 44.0
## Classificação relativa: abaixo da posição, faixas finas.
const LISTA_TOPO := 104.0 + Y0
const LISTA_LARGURA := 246.0
const LISTA_LINHA := 34.0
const LISTA_ESPACO := 4.0
const LISTA_PULO := 10.0  # entre o líder e o grupo do jogador, quando não são vizinhos
const FAIXA := Color(0, 0, 0, 0.42)
const TEXTO_ESCURO := Color(0.09, 0.09, 0.1)
## Volta e tempos: canto superior direito.
const TEMPOS_LARGURA := 214.0
const TEMPOS_LINHA := 28.0
## Evento: entra subindo um pouco, fica e sai devagar.
const EVENTO_ENTRA_S := 0.4
const EVENTO_POP_S := 0.32
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
var _linhas: Array = []  # [[Rect2, id]] da classificação desenhada (toque escolhe a câmera)


func _init() -> void:
	# Só a classificação recebe toque (ver _has_point); o resto passa adiante.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## d: posicao, total, volta, voltas, tempo_volta, melhor (s ou -1), kmh, marcha,
## giro, corte, giro_max; lista: [{id, nome, cor, voce, camera, gap, ataque}] em
## ordem (gap: s atrás do líder; ataque: está atacando o jogador).
func definir(d: Dictionary) -> void:
	var pos := int(d.get("posicao", 0))
	if _pos_antes > 0 and pos > 0 and pos != _pos_antes:
		_t_pos = Time.get_ticks_msec() / 1000.0
		_pos_ganhou = pos < _pos_antes
	_pos_antes = pos
	_d = d
	_mover_agulha()
	queue_redraw()


## Placa de posição: ao ganhar, cresce e brilha em ocre; ao perder, treme em
## vermelho. Dura POS_PULSO_S.
const POS_PULSO_S := 0.9
var _pos_antes := 0
var _t_pos := -INF
var _pos_ganhou := true


## 0..1 do pulso da posição (1 = acabou de mudar).
func _pulso_pos() -> float:
	if Preferencias.reduzir_animacoes:
		return 0.0
	var t := Time.get_ticks_msec() / 1000.0 - _t_pos
	return 0.0 if t < 0.0 or t > POS_PULSO_S else 1.0 - t / POS_PULSO_S


## Agulha viva: segue o giro por uma mola pouco amortecida (passa um pouco do
## ponto na troca de marcha e volta) e treme de leve, mais forte em giro alto.
## Só visual: o giro da simulação não muda.
const AGULHA_MOLA := 260.0
const AGULHA_AMORTECIMENTO := 0.42
const AGULHA_TREMOR := 0.018  # fração da escala, no giro máximo
var _agulha := 0.0
var _agulha_v := 0.0
var _agulha_t := -1.0
var _kmh_vis := 0.0
## Fração da velocidade máxima a partir da qual o km/h fica dourado.
const KMH_DOURADO := 0.93


func _mover_agulha() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	var dt := clampf(agora - _agulha_t, 0.0, 0.05) if _agulha_t >= 0.0 else 0.0
	_agulha_t = agora
	# km/h contando até o valor, sem saltar.
	var kmh := float(_d.get("kmh", 0.0))
	_kmh_vis = kmh if dt <= 0.0 or Preferencias.reduzir_animacoes else lerpf(_kmh_vis, kmh, clampf(dt * 9.0, 0.0, 1.0))
	var giro_max := float(_d.get("giro_max", 0.0))
	if giro_max <= 0.0:
		return
	var giro := float(_d.get("giro", 0.0))
	var u := clampf(giro / giro_max, 0.0, 1.0)
	var tremor := (sin(agora * 31.0) + 0.6 * sin(agora * 53.7 + 1.3) + 0.35 * sin(agora * 89.1)) / 1.95
	var alvo := u + tremor * AGULHA_TREMOR * (0.35 + 0.65 * u)
	if dt <= 0.0:
		_agulha = alvo
		return
	var amort := 2.0 * sqrt(AGULHA_MOLA) * AGULHA_AMORTECIMENTO
	var passos := 4
	var h := dt / passos
	for k in passos:
		_agulha_v += ((alvo - _agulha) * AGULHA_MOLA - _agulha_v * amort) * h
		_agulha += _agulha_v * h
	_agulha = clampf(_agulha, -0.02, 1.04)


## Acontecimento da corrida: título e linha de baixo, no centro. Um por vez:
## prioridade maior substitui; menor espera a vez (e expira se demorar).
## `fica_s` < 0: até limpar_evento() (a chegada).
func evento(titulo: String, sub := "", cor := COR, prio := 1, fica_s := EVENTO_FICA_S, grande := false,
		ouro := false) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	var e := {"titulo": titulo, "sub": sub, "cor": cor, "prio": prio, "t": 0.0, "fica": fica_s, "grande": grande,
			"pedido": agora, "ouro": ouro}
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


## Largada: s que faltam na contagem (< 0 = sem contagem). Três luzes
## vermelhas acendem uma a uma; somem no zero.
var contagem := -1.0:
	set(v):
		contagem = v
		queue_redraw()
## Chegada: a bandeira quadriculada cruza a tela uma vez.
const BANDEIRA_S := 1.1
var _t_bandeira := -INF


func bandeirada() -> void:
	if not Preferencias.reduzir_animacoes:
		_t_bandeira = Time.get_ticks_msec() / 1000.0
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
	var bandeira := Time.get_ticks_msec() / 1000.0 - _t_bandeira < BANDEIRA_S
	if _evento.is_empty() and is_equal_approx(antes, _sec) and _sec == secundario and not bandeira:
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
	_desenhar_contagem()
	_desenhar_bandeira()
	if so_eventos:
		_desenhar_evento()
		return
	if _d.is_empty():
		return
	var f := Tipografia.fonte_numero()
	var x := 18.0
	# Posição: o número grande em âmbar (é o seu); o rótulo e o total pequenos.
	var pos := str(_d["posicao"])
	var w := f.get_string_size(pos, HORIZONTAL_ALIGNMENT_LEFT, -1, 80).x
	var p := _pulso_pos()
	if p > 0.0:
		# Ganhou: cresce com um passo além e um halo ocre. Perdeu: treme em vermelho.
		var centro := Vector2(x + w * 0.5, 84 + Y0 - 30.0)
		var esc := 1.0 + (0.38 * sin(p * PI) if _pos_ganhou else 0.0)
		var lado := sin((1.0 - p) * 46.0) * 7.0 * p if not _pos_ganhou else 0.0
		if _pos_ganhou:
			draw_circle(centro, 46.0 + 30.0 * (1.0 - p), Color(AMBAR, 0.28 * p))
		draw_set_transform(centro + Vector2(lado, 0), 0.0, Vector2(esc, esc))
		var cor_p := AMBAR.lerp(Color(1, 0.95, 0.75), p * 0.6) if _pos_ganhou else AMBAR.lerp(CORTE, p)
		_texto(pos, Vector2(x, 84 + Y0) - centro, 80, cor_p, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
		draw_set_transform(Vector2.ZERO)
	else:
		_texto(pos, Vector2(x, 84 + Y0), 80, AMBAR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	_texto("POS", Vector2(x + w + 8, 50 + Y0), 16, APAGADO, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Tipografia.fonte("semibold"))
	_texto("/%d" % _d["total"], Vector2(x + w + 6, 84 + Y0), 28, SUAVE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	_tempos()
	_lista()
	_conta_giros()
	_desenhar_evento()


## Volta (número grande, total pequeno) e, embaixo, faixas finas com o tempo da
## volta (e a diferença para a melhor no mesmo ponto) e a melhor volta.
func _tempos() -> void:
	var f := Tipografia.fonte_numero()
	var direita := size.x - 18.0
	var total := "/%d" % _d["voltas"]
	var wt := f.get_string_size(total, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	_texto(total, Vector2(direita - wt, 84 + Y0), 26, SUAVE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	var volta := str(_d["volta"])
	var wv := f.get_string_size(volta, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	_texto(volta, Vector2(direita - wt - 4 - wv, 84 + Y0), 56, COR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	_texto("VOLTA", Vector2(direita - wt - 4 - wv - 90, 84 + Y0), 16, APAGADO, HORIZONTAL_ALIGNMENT_RIGHT, 82.0,
			Tipografia.fonte("semibold"))
	var y := 98.0 + Y0
	var x0 := size.x - TEMPOS_LARGURA
	var a := _alfa_inst()
	var delta := float(_d.get("delta", INF))
	_faixa_tempo(Rect2(x0, y, TEMPOS_LARGURA, TEMPOS_LINHA), "ATUAL", _tempo(float(_d.get("tempo_volta", 0.0))),
			"" if delta == INF else "%+.2f" % delta, (Color(CORTE) if delta > 0.0 else AMBAR), a)
	var melhor := float(_d.get("melhor", -1.0))
	if melhor > 0.0:
		_faixa_tempo(Rect2(x0, y + TEMPOS_LINHA + LISTA_ESPACO, TEMPOS_LARGURA, TEMPOS_LINHA), "MELHOR",
				_tempo(melhor), "", COR, a)


func _faixa_tempo(r: Rect2, rotulo: String, valor: String, extra: String, cor_extra: Color, a: float) -> void:
	draw_rect(r, _a(FAIXA, a))
	var base := r.position.y + r.size.y * 0.5 + 6.0
	var fr := Tipografia.fonte("semibold")
	draw_string(fr, Vector2(r.position.x + 10, base), rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, _a(APAGADO, a))
	var fn := Tipografia.fonte_numero()
	draw_string(fn, Vector2(r.position.x, base + 1), valor, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 10, 19, _a(COR, a))
	if extra != "":
		var wv := fn.get_string_size(valor, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_string(fr, Vector2(r.position.x, base), extra, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18 - wv, 15,
				_a(cor_extra, a))


## Instrumentos analógicos, minimalistas: arcos finos concêntricos, sem escala
## nem números no mostrador; o ponteiro é uma linha fina com uma cápsula curta
## em ocre junto ao eixo. Só o que a simulação calcula: giro, marcha e
## velocidade no conta-giros (os tempos da volta ficam nas faixas de cima). Fica no plano secundário: apagam com `_sec` na disputa e na
## chegada.

const GIRO_RAIO := 96.0
const GIRO_ARCO := 135.0  # graus: da esquerda do eixo (180°) ao alto-direita (315°)
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
		_ponteiro(c, GIRO_RAIO, lerpf(de, ate, _agulha), cor, a)
	var marcha := int(_d.get("marcha", 0))
	_txt_inst(str(marcha) if marcha > 0 else "N", c + Vector2(GIRO_RAIO * 0.42, -GIRO_RAIO * 0.12), 40, _a(COR, a), "numero")
	var kmh_max := float(_d.get("kmh_max", 0.0))
	var no_limite := kmh_max > 0.0 and _kmh_vis >= kmh_max * KMH_DOURADO
	_txt_inst("%d km/h" % roundi(_kmh_vis), c + Vector2(GIRO_RAIO * 0.42 + 30.0, -GIRO_RAIO * 0.12), 24 if no_limite else 22,
			_a(AMBAR if no_limite else SUAVE, a), "semibold" if no_limite else "medium")


func _desenhar_contagem() -> void:
	if contagem < 0.0:
		return
	var acesas := clampi(4 - ceili(contagem), 1, 3)
	var c := Vector2(size.x * 0.5, size.y * 0.36)
	var r := 30.0
	var passo := 84.0
	var caixa := Rect2(c.x - passo * 1.5 - 8.0, c.y - r - 18.0, passo * 3.0 + 16.0, r * 2.0 + 36.0)
	draw_rect(caixa, Color(0.05, 0.05, 0.06, 0.82))
	for k in 3:
		var p := c + Vector2((k - 1) * passo, 0.0)
		var acesa := k < acesas
		if acesa:
			draw_circle(p, r * 1.35, Color(CORTE, 0.25))
		draw_circle(p, r, Color(0.95, 0.18, 0.12) if acesa else Color(0.22, 0.08, 0.08))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.35 if acesa else 0.06))
	var n := str(ceili(contagem))
	_texto(n, Vector2(0, caixa.end.y + 64.0), 64, COR, HORIZONTAL_ALIGNMENT_CENTER, size.x, Tipografia.fonte_numero())


## Bandeira quadriculada que atravessa a tela inclinada, da esquerda para a
## direita, na chegada.
func _desenhar_bandeira() -> void:
	var t := Time.get_ticks_msec() / 1000.0 - _t_bandeira
	if t < 0.0 or t > BANDEIRA_S:
		return
	var u := smoothstep(0.0, 1.0, t / BANDEIRA_S)
	var lado := 26.0
	var faixa := 7
	var largura := faixa * lado
	var x0 := lerpf(-largura - 120.0, size.x + 120.0, u)
	var a := 1.0 - smoothstep(0.75, 1.0, t / BANDEIRA_S)
	draw_set_transform(Vector2(x0, size.y * 0.5), deg_to_rad(-12.0), Vector2.ONE)
	var linhas := int(size.y / lado) + 12
	for j in linhas:
		for i in faixa:
			var claro := (i + j) % 2 == 0
			draw_rect(Rect2(i * lado, (j - linhas * 0.5) * lado, lado, lado),
					Color(0.95, 0.95, 0.93, 0.85 * a) if claro else Color(0.05, 0.05, 0.06, 0.85 * a))
	draw_set_transform(Vector2.ZERO)


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
		_texto(String(_evento["titulo"]), Vector2(0, cy), 38, Color(_evento["cor"], a), HORIZONTAL_ALIGNMENT_CENTER, size.x,
				Tipografia.fonte("semibold"))
		if String(_evento["sub"]) != "":
			_texto(String(_evento["sub"]), Vector2(0, cy + 34), 26, Color(COR, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, size.x,
					Tipografia.fonte("medium"))
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
	if _evento.get("ouro", false):
		# Destaque (última volta): filetes ocre em cima e embaixo da faixa.
		var w := size.x * 0.5 * smoothstep(0.0, EVENTO_ENTRA_S, t)
		draw_line(Vector2(size.x * 0.5 - w, y0), Vector2(size.x * 0.5 + w, y0), Color(AMBAR, a), 3.0)
		draw_line(Vector2(size.x * 0.5 - w, y0 + alt), Vector2(size.x * 0.5 + w, y0 + alt), Color(AMBAR, a), 3.0)
	var ft := Tipografia.fonte("semibold")
	var fs := Tipografia.fonte("medium")
	# Entrada com um passo além: o título chega grande e assenta (escala 1,3 →
	# 0,96 → 1). Fica centrado no próprio texto.
	var esc := 1.0
	if not Preferencias.reduzir_animacoes:
		var u := clampf(t / EVENTO_POP_S, 0.0, 1.0)
		esc = lerpf(1.3, 0.96, smoothstep(0.0, 1.0, u / 0.65)) if u < 0.65 \
				else lerpf(0.96, 1.0, smoothstep(0.0, 1.0, (u - 0.65) / 0.35))
	draw_set_transform(Vector2(size.x * 0.5, cy), 0.0, Vector2(esc, esc))
	var o := Vector2(-size.x * 0.5, -cy)
	if grande:
		# Chegada: a linha pequena em cima, a posição enorme embaixo.
		_texto(String(_evento["titulo"]), o + Vector2(0, cy - 44), tam_t, Color(COR, a), HORIZONTAL_ALIGNMENT_CENTER, size.x, ft)
		_texto(String(_evento["sub"]), o + Vector2(0, cy + 52), tam_s, Color(cor, a), HORIZONTAL_ALIGNMENT_CENTER, size.x,
				Tipografia.fonte_numero())
		draw_set_transform(Vector2.ZERO)
		return
	_texto(String(_evento["titulo"]), o + Vector2(0, cy), tam_t + 6, Color(cor, a), HORIZONTAL_ALIGNMENT_CENTER, size.x, ft)
	draw_set_transform(Vector2.ZERO)
	if String(_evento["sub"]) != "":
		_texto(String(_evento["sub"]), Vector2(0, cy + 36), tam_s, Color(COR, a * 0.85), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs)


func _has_point(p: Vector2) -> bool:
	if so_eventos:
		return false
	for l in _linhas:
		if (l[0] as Rect2).has_point(p):
			return true
	return false


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if not toque:
		return
	for l in _linhas:
		if (l[0] as Rect2).has_point(e.position):
			escolhido.emit(String(l[1]))
			accept_event()
			return


## Linhas da classificação relativa: índices em `lista` (líder, à frente, você,
## atrás), sem repetir; -1 marca o pulo entre o líder e o grupo.
static func linhas_relativas(lista: Array) -> Array:
	var eu := -1
	for i in lista.size():
		if lista[i].get("voce", false):
			eu = i
	if eu < 0:
		return range(mini(lista.size(), 4))
	var grupo: Array = []
	for i in [eu - 1, eu, eu + 1]:
		if i >= 0 and i < lista.size():
			grupo.append(i)
	if grupo[0] > 0:
		if grupo[0] > 1:
			grupo.push_front(-1)
		grupo.push_front(0)
	return grupo


## Classificação relativa: faixas escuras translúcidas, sem moldura. A sua
## linha invertida em âmbar (texto escuro). Diferença em segundos para você
## (o líder, para o líder); vermelho em quem está atacando. Uma linha fina à
## esquerda marca o carro que a câmera segue; tocar numa linha a leva para ele.
func _lista() -> void:
	_linhas = []
	var lista: Array = _d.get("lista", [])
	if lista.is_empty():
		return
	var gap_eu := 0.0
	for it in lista:
		if it.get("voce", false):
			gap_eu = float(it.get("gap", 0.0))
	var fn := Tipografia.fonte_numero()
	var fr := Tipografia.fonte("semibold")
	var x0 := 18.0
	var y := LISTA_TOPO
	# Todos os competidores, em ordem; com muitos, as linhas encolhem para caber
	# até a altura do conta-giros.
	var livre := size.y - LISTA_TOPO - GIRO_RAIO - 90.0
	var linha := clampf(livre / maxf(lista.size(), 1.0) - LISTA_ESPACO, 22.0, LISTA_LINHA)
	for i in lista.size():
		var it: Dictionary = lista[i]
		var voce: bool = it.get("voce", false)
		var ataque: bool = it.get("ataque", false)
		var r := Rect2(x0, y, LISTA_LARGURA, linha)
		_linhas.append([r, it["id"]])
		var forca := 1.0 if voce or ataque else lerpf(0.6, 0.9, _sec)
		draw_rect(r, AMBAR if voce else Color(FAIXA, FAIXA.a * forca))
		draw_rect(Rect2(x0, y, 4.0, linha), Color(it["cor"], forca))
		if it.get("camera", false) and not voce:
			draw_rect(Rect2(x0 - 6.0, y + 4.0, 2.0, linha - 8.0), Color(COR, 0.7))
		var cor := TEXTO_ESCURO if voce else Color(COR, forca)
		var base := y + linha * 0.5 + 7.0
		draw_string(fn, Vector2(x0 + 8.0, base + 1.0), str(i + 1), HORIZONTAL_ALIGNMENT_RIGHT, 26.0, 20, cor)
		var gap := float(it.get("gap", -1.0))
		var gap_txt := ""
		if gap >= 0.0 and not voce:
			var rel := gap - gap_eu  # negativo: à sua frente
			gap_txt = "%+.1f" % rel if absf(rel) < 60.0 else ("+1 v" if rel > 0.0 else "-1 v")
		var wg := fr.get_string_size(gap_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x if gap_txt != "" else 0.0
		var nome: String = it["nome"]
		var max_l := LISTA_LARGURA - 46.0 - wg - 14.0
		if fr.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x > max_l:
			while nome.length() > 3 and fr.get_string_size(nome + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x > max_l:
				nome = nome.left(-1)
			nome += "…"
		draw_string(fr, Vector2(x0 + 44.0, base), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, cor)
		if gap_txt != "":
			draw_string(fr, Vector2(x0, base), gap_txt, HORIZONTAL_ALIGNMENT_RIGHT, LISTA_LARGURA - 10.0, 17,
					Color(CORTE, 0.95) if ataque else Color(COR, forca * 0.75))
		y += linha + LISTA_ESPACO
	if _d.get("ultima", false) and not _linhas.is_empty():
		# Última volta: contorno ocre na classificação, pulsando devagar.
		var pulso := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 1.4)
		var topo: Rect2 = _linhas[0][0]
		var fim: Rect2 = _linhas[-1][0]
		draw_rect(Rect2(topo.position - Vector2(4, 4), Vector2(LISTA_LARGURA + 8.0, fim.end.y - topo.position.y + 8.0)),
				Color(AMBAR, pulso), false, 2.0)


static func _tempo(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(maxf(t, 0.0), 60.0)]
