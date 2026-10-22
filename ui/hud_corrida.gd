class_name HudCorrida
extends Control
## Painel da corrida sobre a pista (revisão da corrida, decisão 131): só três
## lugares, para o olho ficar no carro.
##   - Faixa de cima: a posição grande à esquerda e a volta à direita (o canto
##     da direita fica livre para o botão ••• da tela da corrida).
##   - Logo abaixo: quem está à frente e quem está atrás, com a diferença em
##     segundos. Um toque abre a classificação inteira (e outro fecha); na
##     classificação aberta, tocar num carro leva a câmera para ele.
##   - Perto do seu carro: as notas e os acontecimentos curtos, saindo dele
##     (`ancora_carro`). A chegada fica no centro; a última volta, embaixo da
##     faixa.
## Sem conta-giros, km/h, tempos de volta nem minimapa durante a corrida: o
## som, a imagem e a vista DADOS já dão isso.
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
## Semáforo da largada (arte/ui/semaforo.png): altura na tela e as lentes, em
## frações da imagem (centro x, centro y de cada uma, raio pela largura).
const SEMAFORO_ALTURA := 300.0
const SEMAFORO_X := 0.493
const SEMAFORO_Y := [0.2144, 0.5323, 0.8406]
const SEMAFORO_RAIO := 0.2
## Faixa de cima e as linhas dos vizinhos.
const BANDA := 78.0
const RESERVA_MENU := 74.0  # canto da direita, do botão •••
const VIZINHO_LINHA := 30.0
const VIZINHO_LARGURA := 270.0
## Classificação aberta.
const LISTA_LARGURA := 270.0
const LISTA_LINHA := 32.0
const LISTA_ESPACO := 4.0
const FAIXA := Color(0, 0, 0, 0.42)
const FAIXA_FORTE := Color(0.03, 0.035, 0.05, 0.72)
const TEXTO_ESCURO := Color(0.09, 0.09, 0.1)
## Acontecimento: entra subindo um pouco, fica e sai devagar.
const EVENTO_ENTRA_S := 0.4
const EVENTO_POP_S := 0.32
const EVENTO_SAI_S := 0.7
const EVENTO_FICA_S := 2.2
const EVENTO_PENDENTE_MAX_S := 3.0
## Acima do carro: a nota sai deste tanto acima do ponto do carro na tela.
const ACIMA_DO_CARRO := 140.0
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
## Áreas que recebem toque: [[Rect2, id]]; id "" abre/fecha a classificação.
var _linhas: Array = []
## Classificação inteira aberta (toque nos vizinhos).
var expandida := false
## Ponto do seu carro na tela, nas coordenadas deste painel (-1: sem carro).
var ancora_carro := Vector2(-1, -1)


func _init() -> void:
	textura_semaforo()  # fora do desenho (ver textura_semaforo)
	# Só os vizinhos e a classificação recebem toque (ver _has_point); o resto
	# (o pedal da pilotagem) passa adiante.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## d: posicao, total, volta, voltas, ultima; lista: [{id, nome, cor, voce,
## camera, gap, ataque}] em ordem (gap: s atrás do líder; ataque: está
## atacando o jogador).
func definir(d: Dictionary) -> void:
	var pos := int(d.get("posicao", 0))
	if _pos_antes > 0 and pos > 0 and pos != _pos_antes:
		_t_pos = Time.get_ticks_msec() / 1000.0
		_pos_ganhou = pos < _pos_antes
	_pos_antes = pos
	_d = d
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


## Acontecimento da corrida: título e linha de baixo. Um por vez: prioridade
## maior substitui; menor espera a vez (e expira se demorar). `fica_s` < 0:
## até limpar_evento() (a chegada). `grande`: no centro (a chegada); `ouro`:
## destaque embaixo da faixa (a última volta); os outros saem do seu carro.
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
	_linhas = []
	if so_eventos:
		_desenhar_evento()
		return
	if _d.is_empty():
		return
	_banda()
	_vizinhos()
	if expandida:
		_lista()
	_desenhar_evento()


## Faixa de cima: a posição grande (âmbar, é a sua) e o total pequeno; a volta
## à direita, antes do canto do •••. Na última volta, ÚLTIMA VOLTA em âmbar.
func _banda() -> void:
	# Escura no alto, sumindo embaixo: lê-se sobre qualquer pista.
	var topo := Color(0.02, 0.025, 0.035, 0.78)
	var fim := Color(0.02, 0.025, 0.035, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, BANDA + 18.0),
			Vector2(0, BANDA + 18.0)]), PackedColorArray([topo, topo, fim, fim]))
	var f := Tipografia.fonte_numero()
	var x := 16.0
	var base := BANDA - 14.0
	var pos := str(_d["posicao"])
	var w := f.get_string_size(pos, HORIZONTAL_ALIGNMENT_LEFT, -1, 66).x
	var p := _pulso_pos()
	if p > 0.0:
		# Ganhou: cresce com um passo além e um halo ocre. Perdeu: treme em vermelho.
		var centro := Vector2(x + w * 0.5, base - 24.0)
		var esc := 1.0 + (0.38 * sin(p * PI) if _pos_ganhou else 0.0)
		var lado := sin((1.0 - p) * 46.0) * 7.0 * p if not _pos_ganhou else 0.0
		if _pos_ganhou:
			draw_circle(centro, 40.0 + 26.0 * (1.0 - p), Color(AMBAR, 0.28 * p))
		draw_set_transform(centro + Vector2(lado, 0), 0.0, Vector2(esc, esc))
		var cor_p := AMBAR.lerp(Color(1, 0.95, 0.75), p * 0.6) if _pos_ganhou else AMBAR.lerp(CORTE, p)
		_texto(pos, Vector2(x, base) - centro, 66, cor_p, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
		draw_set_transform(Vector2.ZERO)
	else:
		_texto(pos, Vector2(x, base), 66, AMBAR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	_texto("º", Vector2(x + w + 2, base - 30), 26, AMBAR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	_texto("/%d" % _d["total"], Vector2(x + w + 18, base), 26, SUAVE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	var direita := size.x - RESERVA_MENU
	var fr := Tipografia.fonte("semibold")
	if _d.get("ultima", false):
		var pulso := 0.7 + 0.3 * sin(Time.get_ticks_msec() / 1000.0 * TAU / 1.4)
		_texto("ÚLTIMA VOLTA", Vector2(direita - 220.0, base - 6.0), 26, Color(AMBAR, pulso), HORIZONTAL_ALIGNMENT_RIGHT,
				220.0, fr)
		return
	var total := "/%d" % _d["voltas"]
	var wt := f.get_string_size(total, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_texto(total, Vector2(direita - wt, base), 24, SUAVE, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	var volta := str(_d["volta"])
	var wv := f.get_string_size(volta, HORIZONTAL_ALIGNMENT_LEFT, -1, 46).x
	_texto(volta, Vector2(direita - wt - 4 - wv, base), 46, COR, HORIZONTAL_ALIGNMENT_LEFT, -1.0, f)
	_texto("VOLTA", Vector2(direita - wt - 4 - wv - 86, base - 6.0), 16, APAGADO, HORIZONTAL_ALIGNMENT_RIGHT, 80.0, fr)


## Quem está à frente e quem está atrás, com a diferença em segundos (o de
## trás em vermelho quando está atacando). Tocar abre a classificação.
func _vizinhos() -> void:
	var lista: Array = _d.get("lista", [])
	var eu := -1
	for i in lista.size():
		if lista[i].get("voce", false):
			eu = i
	if eu < 0:
		return
	var y := BANDA + 4.0
	var linhas := []
	if eu > 0:
		linhas.append([lista[eu - 1], true])
	if eu + 1 < lista.size():
		linhas.append([lista[eu + 1], false])
	var a := lerpf(0.75, 1.0, _sec)
	var fr := Tipografia.fonte("semibold")
	var area := Rect2(10.0, y, VIZINHO_LARGURA, maxf(linhas.size(), 1) * (VIZINHO_LINHA + 3.0))
	_linhas.append([area, ""])
	if linhas.is_empty():
		return
	var gap_eu := float(lista[eu].get("gap", 0.0))
	for l in linhas:
		var it: Dictionary = l[0]
		var frente: bool = l[1]
		var r := Rect2(10.0, y, VIZINHO_LARGURA, VIZINHO_LINHA)
		draw_rect(r, _a(FAIXA, a))
		draw_rect(Rect2(r.position, Vector2(4.0, r.size.y)), _a(Color(it["cor"]), a))
		# Seta: para cima (à frente) ou para baixo (atrás).
		var c := Vector2(r.position.x + 20.0, r.position.y + r.size.y * 0.5)
		var ataque: bool = it.get("ataque", false)
		var cor_seta := Color(CORTE) if ataque else (AMBAR if frente else SUAVE)
		var dy := -6.0 if frente else 6.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, dy), c + Vector2(-6, -dy), c + Vector2(6, -dy)]),
				_a(cor_seta, a))
		var base := r.position.y + r.size.y * 0.5 + 7.0
		draw_string(fr, Vector2(r.position.x + 34.0, base), String(it["nome"]), HORIZONTAL_ALIGNMENT_LEFT,
				VIZINHO_LARGURA - 110.0, 19, _a(COR, a))
		var gap := float(it.get("gap", -1.0))
		var txt := ""
		if gap >= 0.0:
			var rel := absf(gap - gap_eu)
			txt = ("%.1f s" % rel).replace(".", ",") if rel < 60.0 else "1 volta"
		elif frente:
			txt = "líder"
		draw_string(fr, Vector2(r.position.x, base), txt, HORIZONTAL_ALIGNMENT_RIGHT, VIZINHO_LARGURA - 10.0, 18,
				_a(Color(CORTE) if ataque else SUAVE, a))
		y += VIZINHO_LINHA + 3.0


## Classificação inteira, aberta pelo toque nos vizinhos: faixas escuras, a sua
## em âmbar. Tocar num carro leva a câmera para ele.
func _lista() -> void:
	var lista: Array = _d.get("lista", [])
	if lista.is_empty():
		return
	var gap_eu := 0.0
	for it in lista:
		if it.get("voce", false):
			gap_eu = float(it.get("gap", 0.0))
	var fn := Tipografia.fonte_numero()
	var fr := Tipografia.fonte("semibold")
	var x0 := 10.0
	var y := BANDA + 4.0 + 2.0 * (VIZINHO_LINHA + 3.0) + 8.0
	var linha := clampf((size.y - y - 20.0) / maxf(lista.size(), 1.0) - LISTA_ESPACO, 22.0, LISTA_LINHA)
	draw_rect(Rect2(x0 - 6.0, y - 6.0, LISTA_LARGURA + 12.0, lista.size() * (linha + LISTA_ESPACO) + 8.0), FAIXA_FORTE)
	for i in lista.size():
		var it: Dictionary = lista[i]
		var voce: bool = it.get("voce", false)
		var r := Rect2(x0, y, LISTA_LARGURA, linha)
		_linhas.append([r, it["id"]])
		draw_rect(r, AMBAR if voce else FAIXA)
		draw_rect(Rect2(x0, y, 4.0, linha), Color(it["cor"]))
		if it.get("camera", false) and not voce:
			draw_rect(Rect2(x0 - 6.0, y + 4.0, 2.0, linha - 8.0), Color(COR, 0.7))
		var cor := TEXTO_ESCURO if voce else COR
		var base := y + linha * 0.5 + 7.0
		draw_string(fn, Vector2(x0 + 8.0, base + 1.0), str(i + 1), HORIZONTAL_ALIGNMENT_RIGHT, 26.0, 20, cor)
		draw_string(fr, Vector2(x0 + 44.0, base), String(it["nome"]), HORIZONTAL_ALIGNMENT_LEFT, LISTA_LARGURA - 110.0, 19,
				cor)
		var gap := float(it.get("gap", -1.0))
		if gap >= 0.0 and not voce:
			var rel := gap - gap_eu  # negativo: à sua frente
			var txt := ("%+.1f" % rel).replace(".", ",") if absf(rel) < 60.0 else ("+1 volta" if rel > 0.0 else "-1 volta")
			draw_string(fr, Vector2(x0, base), txt, HORIZONTAL_ALIGNMENT_RIGHT, LISTA_LARGURA - 10.0, 17,
					Color(CORTE, 0.95) if it.get("ataque", false) else Color(COR, 0.75))
		y += linha + LISTA_ESPACO


func _desenhar_contagem() -> void:
	semaforo(self, size, contagem)


## A arte do semáforo, carregada fora do desenho: carregada pela primeira vez
## dentro de um _draw, o renderizador de compatibilidade a mostrava como um
## retângulo branco (relato do teste de 2026-10-21). Quem desenha o semáforo
## chama isto ao ser criado (HudCorrida, LutaArena).
static var _tex_semaforo: Texture2D


static func textura_semaforo() -> Texture2D:
	if _tex_semaforo == null:
		_tex_semaforo = Aba.arte("semaforo")
	return _tex_semaforo


## As três luzes vermelhas da largada e o número, no alto da área `tam` de
## `ci` (a corrida e a arena usam o mesmo). contagem < 0 não desenha.
static func semaforo(ci: CanvasItem, tam: Vector2, contagem: float, altura := 0.36) -> void:
	if contagem < 0.0:
		return
	var acesas := clampi(4 - ceili(contagem), 1, 3)
	var tex := textura_semaforo()
	var alto := SEMAFORO_ALTURA
	var largo := alto * tex.get_width() / tex.get_height()
	var caixa := Rect2(tam.x * 0.5 - largo * 0.5, tam.y * altura - alto * 0.5, largo, alto)
	ci.draw_texture_rect(tex, caixa, false)
	# As lentes acendem de cima para baixo, uma por segundo; a que acabou de
	# acender sobe em 0,15 s com um clarão que assenta.
	var r := largo * SEMAFORO_RAIO
	var desde := float(ceili(contagem)) - contagem  # s desde a última lente acesa
	for k in 3:
		if k >= acesas:
			continue
		var p := caixa.position + Vector2(largo * SEMAFORO_X, alto * SEMAFORO_Y[k])
		var a := 1.0
		var clarao := 0.0
		if k == acesas - 1 and not Preferencias.reduzir_animacoes:
			a = smoothstep(0.0, 0.15, desde)
			clarao = 1.0 - smoothstep(0.1, 0.5, desde)
		ci.draw_circle(p, r * (1.55 + 0.5 * clarao), Color(CORTE, (0.22 + 0.25 * clarao) * a))
		ci.draw_circle(p, r * 1.2, Color(CORTE, 0.3 * a))
		ci.draw_circle(p, r, Color(Color(0.95, 0.16, 0.1), a))
		ci.draw_circle(p + Vector2(-r * 0.32, -r * 0.32), r * 0.3, Color(1, 0.85, 0.8, 0.45 * a))
	var f := Tipografia.fonte_numero()
	var pos := Vector2(0, caixa.end.y + 70.0)
	var n := str(ceili(contagem))
	ci.draw_string_outline(f, pos, n, HORIZONTAL_ALIGNMENT_CENTER, tam.x, 64, 6, SOMBRA)
	ci.draw_string(f, pos, n, HORIZONTAL_ALIGNMENT_CENTER, tam.x, 64, COR)


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


## Onde o acontecimento aparece: a chegada no centro; a última volta embaixo
## da faixa; o resto acima do seu carro (sem carro na tela, a 62% da altura).
func _centro_evento(grande: bool, ouro: bool) -> float:
	if grande:
		return size.y * 0.5
	if ouro:
		return BANDA + 2.0 * (VIZINHO_LINHA + 3.0) + 48.0
	var y := ancora_carro.y - ACIMA_DO_CARRO if ancora_carro.y >= 0.0 else size.y * 0.62
	return clampf(y, BANDA + 2.0 * (VIZINHO_LINHA + 3.0) + 60.0, size.y - 90.0)


## Acontecimento: texto direto sobre a cena, numa faixa escura muito leve só
## para garantir a leitura. Entra subindo 10 px, sai devagar.
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
	var ouro: bool = _evento.get("ouro", false)
	var cy := _centro_evento(grande, ouro) + (1.0 - smoothstep(0.0, EVENTO_ENTRA_S, t)) * 10.0
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
	var tam_t := 30
	var tam_s := 110 if grande else 20
	var ft := Tipografia.fonte("semibold")
	var fs := Tipografia.fonte("medium")
	var cor: Color = _evento["cor"]
	if grande:
		# Chegada: faixa larga e a posição enorme.
		var alt := 150.0
		var y0 := cy - alt * 0.62
		var meio := Color(0, 0, 0, 0.26 * a)
		var nada := Color(0, 0, 0, 0)
		var xs := [0.0, size.x * 0.25, size.x * 0.75, size.x]
		for i in 3:
			var c0: Color = nada if i == 0 else meio
			var c1: Color = nada if i == 2 else meio
			draw_polygon(PackedVector2Array([Vector2(xs[i], y0), Vector2(xs[i + 1], y0), Vector2(xs[i + 1], y0 + alt),
					Vector2(xs[i], y0 + alt)]), PackedColorArray([c0, c1, c1, c0]))
	else:
		# Os outros: uma pílula escura só do tamanho do texto.
		var w := maxf(ft.get_string_size(String(_evento["titulo"]), HORIZONTAL_ALIGNMENT_LEFT, -1, tam_t).x,
				fs.get_string_size(String(_evento["sub"]), HORIZONTAL_ALIGNMENT_LEFT, -1, tam_s).x) + 36.0
		w = minf(w, size.x - 20.0)
		var alt := 44.0 if String(_evento["sub"]) == "" else 70.0
		draw_rect(Rect2(size.x * 0.5 - w * 0.5, cy - 32.0, w, alt), Color(0, 0, 0, 0.38 * a))
		if ouro:
			draw_line(Vector2(size.x * 0.5 - w * 0.5, cy - 32.0), Vector2(size.x * 0.5 + w * 0.5, cy - 32.0), Color(AMBAR, a), 3.0)
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
		# Chegada: a linha pequena em cima, a posição enorme embaixo (as duas
		# encolhem para caber na largura).
		var fn := Tipografia.fonte_numero()
		_texto(String(_evento["titulo"]), o + Vector2(0, cy - 44), _cabe(String(_evento["titulo"]), ft, tam_t), Color(COR, a),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, ft)
		_texto(String(_evento["sub"]), o + Vector2(0, cy + 52), _cabe(String(_evento["sub"]), fn, tam_s), Color(cor, a),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, fn)
		draw_set_transform(Vector2.ZERO)
		return
	_texto(String(_evento["titulo"]), o + Vector2(0, cy), _cabe(String(_evento["titulo"]), ft, tam_t), Color(cor, a),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, ft)
	draw_set_transform(Vector2.ZERO)
	if String(_evento["sub"]) != "":
		_texto(String(_evento["sub"]), Vector2(0, cy + 26), _cabe(String(_evento["sub"]), fs, tam_s), Color(COR, a * 0.85),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, fs)


## Tamanho de fonte até `tam` em que o texto cabe em 92% da largura.
func _cabe(t: String, f: Font, tam: int) -> int:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	return tam if w <= size.x * 0.92 or w <= 0.0 else maxi(int(tam * size.x * 0.92 / w), 12)


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
	# A classificação (aberta) antes dos vizinhos: ela fica por cima.
	for k in range(_linhas.size() - 1, -1, -1):
		var l: Array = _linhas[k]
		if (l[0] as Rect2).has_point(e.position):
			if String(l[1]) == "":
				expandida = not expandida
			else:
				escolhido.emit(String(l[1]))
				expandida = false
			queue_redraw()
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


static func _tempo(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(maxf(t, 0.0), 60.0)]
