class_name PedalPilotagem
extends Control
## A marca da pilotagem por toques (decisões 127 e 131) na tela da corrida: uma
## régua na zona do polegar. Antes de cada curva o cursor corre até a faixa da
## freada (FREIE NO VERDE): encostar o dedo com o cursor nela é a freada certa;
## segurando, a régua passa a correr até a saída (SOLTE NO VERDE). Na
## largada, só o aviso (o semáforo é a marca). No deslize (defesa e vácuo), a
## seta do lado certo e o tempo que resta para deslizar o dedo.
## Só desenha; quem decide é a tela da corrida (Pilotagem).

const LARGURA := 560.0
const ALTURA := 44.0
const COR_FUNDO := Color(0.05, 0.06, 0.08, 0.55)
const COR_ALVO := Color(0.36, 0.82, 0.47)
const COR_BOA := Color(0.36, 0.82, 0.47, 0.35)
const COR_CURSOR := Color(1, 1, 1)
const COR_SAIDA := Color("d6a23e")

## "" (escondida), "frenagem" (também a saída da curva), "largada" ou "defesa"
## (o deslize: defesa e vácuo).
var modo := ""
## Frenagem: segundos até o ponto de frenagem (negativo: já passou) e as
## tolerâncias, para desenhar a faixa.
var faltam_s := 0.0
var janela_s := 2.5
var perfeita_s := 0.25
var boa_s := 0.5
## Deslize: 0..1 do tempo que resta e o lado certo (-1 esquerda, 1 direita).
var fracao := 0.0
var lado := 0
var _rotulo: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(LARGURA, ALTURA + 60)
	_rotulo = Label.new()
	_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_rotulo.offset_bottom = 56
	Tipografia.rotulo(_rotulo, "semibold", 40)
	_rotulo.add_theme_constant_override("outline_size", 6)
	_rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)


func frenagem(faltam: float, janela: float, perfeita: float, boa: float, texto := "FREIE NO VERDE") -> void:
	modo = "frenagem"
	faltam_s = faltam
	janela_s = janela
	perfeita_s = perfeita
	boa_s = boa
	_rotulo.text = texto
	_rotulo.add_theme_color_override("font_color", COR_ALVO if absf(faltam) <= perfeita else Color.WHITE)
	visible = true
	queue_redraw()


func largada() -> void:
	modo = "largada"
	_rotulo.text = "TOQUE QUANDO APAGAR"
	_rotulo.add_theme_color_override("font_color", Color.WHITE)
	visible = true
	queue_redraw()


## lado_: -1 esquerda, 1 direita; passou: 0..1 do tempo para deslizar.
func defesa(lado_: int, passou: float, texto := "") -> void:
	modo = "defesa"
	lado = lado_
	fracao = clampf(1.0 - passou, 0.0, 1.0)
	_rotulo.text = texto if texto != "" else ("DESLIZE PARA A ESQUERDA" if lado < 0 else "DESLIZE PARA A DIREITA")
	_rotulo.add_theme_color_override("font_color", COR_SAIDA)
	visible = true
	queue_redraw()


func esconder() -> void:
	modo = ""
	visible = false


func _draw() -> void:
	if modo == "largada":
		return
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
	elif modo == "defesa":
		# O tempo que resta encolhe para o meio; a seta aponta o lado do rival.
		var meio := r.position.x + r.size.x * 0.5
		var w := r.size.x * 0.5 * fracao
		draw_rect(Rect2(meio - w, r.position.y, 2.0 * w, r.size.y), Color(COR_SAIDA, 0.45))
		var ponta := Vector2(r.position.x + 18.0 if lado < 0 else r.end.x - 18.0, r.get_center().y)
		var tras := ponta.x + (34.0 if lado < 0 else -34.0)
		draw_colored_polygon(PackedVector2Array([ponta, Vector2(tras, r.position.y + 4.0),
				Vector2(tras, r.end.y - 4.0)]), COR_SAIDA)
	draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
