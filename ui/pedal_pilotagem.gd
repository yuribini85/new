class_name PedalPilotagem
extends Control
## A marca da pilotagem por toques (decisão 127) na tela da corrida: uma régua
## no pé da pista. Antes de cada curva o cursor corre até a faixa da frenagem
## (FREIE): tocar com o cursor na faixa é a freada certa. Na saída da curva a
## régua vira a barra da saída (SEGURE), que enche enquanto o dedo segura.
## Só desenha; quem decide é a tela da corrida (Pilotagem).

const LARGURA := 420.0
const ALTURA := 26.0
const COR_FUNDO := Color(0.05, 0.06, 0.08, 0.55)
const COR_ALVO := Color(0.36, 0.82, 0.47)
const COR_BOA := Color(0.36, 0.82, 0.47, 0.35)
const COR_CURSOR := Color(1, 1, 1)
const COR_SAIDA := Color("d6a23e")

## "" (escondida), "frenagem" ou "saida".
var modo := ""
## Frenagem: segundos até o ponto de frenagem (negativo: já passou) e as
## tolerâncias, para desenhar a faixa.
var faltam_s := 0.0
var janela_s := 1.5
var perfeita_s := 0.15
var boa_s := 0.35
## Saída: 0..1 do tempo de saída já passado e se o dedo está segurando.
var fracao := 0.0
var segurando := false
var _rotulo: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(LARGURA, ALTURA + 44)
	_rotulo = Label.new()
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_rotulo.offset_bottom = 40
	Tipografia.rotulo(_rotulo, "semibold", 30)
	_rotulo.add_theme_constant_override("outline_size", 6)
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)


func frenagem(faltam: float, janela: float, perfeita: float, boa: float) -> void:
	modo = "frenagem"
	faltam_s = faltam
	janela_s = janela
	perfeita_s = perfeita
	boa_s = boa
	_rotulo.text = "FREIE"
	_rotulo.add_theme_color_override("font_color", COR_ALVO if absf(faltam) <= perfeita else Color.WHITE)
	visible = true
	queue_redraw()


func saida(fracao_: float, segurando_: bool) -> void:
	modo = "saida"
	fracao = clampf(fracao_, 0.0, 1.0)
	segurando = segurando_
	_rotulo.text = "SEGURE"
	_rotulo.add_theme_color_override("font_color", COR_SAIDA if segurando else Color.WHITE)
	visible = true
	queue_redraw()


func esconder() -> void:
	modo = ""
	visible = false


func _draw() -> void:
	var r := Rect2(Vector2((size.x - LARGURA) * 0.5, size.y - ALTURA), Vector2(LARGURA, ALTURA))
	draw_rect(r, COR_FUNDO)
	if modo == "frenagem":
		# O ponto de frenagem fica a 3/4 da régua; à esquerda, o tempo que falta.
		var escala := r.size.x * 0.75 / maxf(janela_s, 0.01)
		var alvo_x := r.position.x + r.size.x * 0.75
		draw_rect(Rect2(alvo_x - boa_s * escala, r.position.y, 2.0 * boa_s * escala, r.size.y), COR_BOA)
		draw_rect(Rect2(alvo_x - perfeita_s * escala, r.position.y, 2.0 * perfeita_s * escala, r.size.y), COR_ALVO)
		var x := clampf(alvo_x - faltam_s * escala, r.position.x, r.end.x)
		draw_rect(Rect2(x - 3.0, r.position.y - 6.0, 6.0, r.size.y + 12.0), COR_CURSOR)
	elif modo == "saida":
		draw_rect(Rect2(r.position, Vector2(r.size.x * fracao, r.size.y)), COR_SAIDA if segurando else Color(1, 1, 1, 0.35))
	draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
