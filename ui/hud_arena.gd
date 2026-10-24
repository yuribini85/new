class_name HudArena
extends Control
## Placar da arena: por equipe, o nome dela (com a posição quando cai) e,
## embaixo, uma linha por carro com o piloto e o modelo; o eliminado apaga e
## leva "FORA". A integridade (os seis quadrados) não fica aqui: a dos carros
## da sua equipe aparece maior embaixo (PainelVidaArena).
## Começa recolhido (só o cabeçalho com quantos restam); um toque no cabeçalho
## abre o placar, que cresce até `altura_max` (quase a tela toda no celular).

const LARGURA_FECHADA := 300.0
const LARGURA := 470.0  # aberto: até o seletor de câmeras, à direita
const CABECALHO := 56.0
const LINHA := 64.0  # altura natural da linha de carro (encolhe para caber)
const EQUIPE := 44.0
const ESCALA_MIN := 0.55
const ESCALA_MAX := 1.5  # com poucos carros as linhas crescem e o placar ocupa a altura
const FUNDO := Color(0.05, 0.05, 0.06, 0.82)
## Toque e o clique que o navegador do celular gera do mesmo toque chegam os
## dois: um só conta.
const TOQUE_MIN_MS := 300

## [{tipo: "equipe", nome, cor, posicao (0 = de pé), eliminado, voce} ou
##  {id, nome, carro, cor, dano, eliminado, voce}]
var linhas: Array = []:
	set(v):
		linhas = v
		queue_redraw()
var recolhida := true
## Altura que o placar aberto pode ocupar (quem mostra ajusta à tela).
var altura_max := 1000.0
var _ultimo_toque := -TOQUE_MIN_MS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if not toque or e.position.y > CABECALHO:
		return
	accept_event()
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_toque < TOQUE_MIN_MS:
		return
	_ultimo_toque = agora
	recolhida = not recolhida
	queue_redraw()


func _draw() -> void:
	var fonte := Tipografia.fonte("semibold")
	var carros := linhas.filter(func(l): return l.has("dano"))
	var vivos := carros.filter(func(l): return not l["eliminado"]).size()
	var largura := LARGURA_FECHADA if recolhida else LARGURA
	draw_rect(Rect2(0, 0, largura, CABECALHO - 4.0), FUNDO)
	draw_rect(Rect2(0, 0, 5, CABECALHO - 4.0), Aba.COR_DESTAQUE)
	draw_string(fonte, Vector2(18, CABECALHO * 0.5 + 9.0), "%d RESTANTES" % vivos,
			HORIZONTAL_ALIGNMENT_LEFT, largura - 70, 26, Color(0.9, 0.9, 0.92))
	var seta := Vector2(largura - 30, CABECALHO * 0.5 - 2.0)
	var pts := PackedVector2Array([seta + Vector2(-11, -6), seta + Vector2(11, -6), seta + Vector2(0, 8)]) if not recolhida \
			else PackedVector2Array([seta + Vector2(-6, -11), seta + Vector2(-6, 11), seta + Vector2(8, 0)])
	draw_colored_polygon(pts, Aba.COR_DESTAQUE)
	var y := CABECALHO
	if not recolhida:
		var equipes := linhas.size() - carros.size()
		var natural := equipes * EQUIPE + carros.size() * LINHA
		var k := clampf((altura_max - CABECALHO) / maxf(natural, 1.0), ESCALA_MIN, ESCALA_MAX)
		for l in linhas:
			if l.get("tipo", "") == "equipe":
				y += _equipe(l, y, k)
			else:
				y += _linha_carro(l, y, k)
	custom_minimum_size = Vector2(largura, y)
	size = custom_minimum_size  # fora de contêiner: a área do toque acompanha o placar


func _linha_carro(l: Dictionary, y: float, k: float) -> float:
	var h := LINHA * k
	var r := Rect2(0, y, LARGURA, h - 4.0 * k)
	draw_rect(r, FUNDO)
	var cor: Color = l["cor"]
	draw_rect(Rect2(r.position, Vector2(6, r.size.y)), cor if not l["eliminado"] else cor.darkened(0.6))
	var fonte := Tipografia.fonte("semibold")
	var cor_nome := Aba.COR_DESTAQUE if l.get("voce", false) else Color(0.93, 0.93, 0.9)
	if l["eliminado"]:
		cor_nome = Color(0.5, 0.5, 0.52)
	var tam := roundi(28 * k)
	var modelo := String(l.get("carro", ""))
	var dois := k >= 0.75 and modelo != ""
	var x := 22.0
	var largura_txt := LARGURA - x - (96.0 if l["eliminado"] else 16.0)
	var meio := y + r.size.y * 0.5
	draw_string(fonte, Vector2(x, meio + (-3.0 if dois else tam * 0.36)), String(l["nome"]),
			HORIZONTAL_ALIGNMENT_LEFT, largura_txt, tam, cor_nome)
	if dois:
		draw_string(Tipografia.fonte("regular"), Vector2(x, meio + 20.0 * k), modelo, HORIZONTAL_ALIGNMENT_LEFT,
				largura_txt, roundi(20 * k), Color(0.45, 0.45, 0.47) if l["eliminado"] else Color(0.66, 0.66, 0.68))
	if l["eliminado"]:
		draw_string(fonte, Vector2(LARGURA - 86, meio + tam * 0.36), "FORA", HORIZONTAL_ALIGNMENT_RIGHT, 72,
				roundi(22 * k), Aba.COR_RUIM)
	return h


## Linha da equipe: faixa na cor dela, a posição (quando já tem) e o nome.
## Devolve a altura usada.
func _equipe(l: Dictionary, y: float, k: float) -> float:
	var h := EQUIPE * k
	var r := Rect2(0, y, LARGURA, h - 3.0 * k)
	var cor: Color = l["cor"]
	draw_rect(r, Color(cor.r, cor.g, cor.b, 0.22 if l["eliminado"] else 0.45).darkened(0.35))
	draw_rect(Rect2(r.position, Vector2(6, r.size.y)), cor)
	var x := 18.0
	var tam := roundi(24 * k)
	var meio := y + r.size.y * 0.5 + tam * 0.36
	if int(l["posicao"]) > 0:
		var txt := "#%d" % int(l["posicao"])
		draw_string(Tipografia.fonte_numero(), Vector2(x, meio), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam + 2,
				Aba.COR_DESTAQUE if int(l["posicao"]) == 1 else Color.WHITE)
		x += Tipografia.fonte_numero().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam + 2).x + 12
	draw_string(Tipografia.fonte("semibold"), Vector2(x, meio), String(l["nome"]).to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, LARGURA - x - 12, tam, Color(0.6, 0.6, 0.6) if l["eliminado"] else Color.WHITE)
	return h
