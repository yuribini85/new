class_name PedalPilotagem
extends Control
## O aviso curto da pilotagem por toques (decisões 127 e 131) na zona do
## polegar: FREIE NO VERDE, SOLTE NO VERDE, FECHE A PORTA... A marca em si fica
## na pista (Corrida3D.deixas e .seta, decisão 131 C2): a faixa verde pintada no
## asfalto e as setas no chão ao lado do carro. Na largada, o semáforo.
## Só mostra; quem decide é a tela da corrida (Pilotagem).

const LARGURA := 560.0
const ALTURA := 0.0
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
	_rotulo.add_theme_color_override("font_color", Color.WHITE)  # o verde é o da pista
	visible = true


func largada() -> void:
	modo = "largada"
	_rotulo.text = "TOQUE QUANDO APAGAR"
	_rotulo.add_theme_color_override("font_color", Color.WHITE)
	visible = true


## lado_: -1 esquerda, 1 direita; passou: 0..1 do tempo para deslizar.
func defesa(lado_: int, passou: float, texto := "") -> void:
	modo = "defesa"
	lado = lado_
	fracao = clampf(1.0 - passou, 0.0, 1.0)
	_rotulo.text = texto if texto != "" else ("DESLIZE PARA A ESQUERDA" if lado < 0 else "DESLIZE PARA A DIREITA")
	_rotulo.add_theme_color_override("font_color", COR_SAIDA)
	visible = true


func esconder() -> void:
	modo = ""
	visible = false
