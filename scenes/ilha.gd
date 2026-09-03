extends Node2D
## Cena principal. Terreno real (bíblia #23.1: composição em camadas) — Mar +
## Ilha_Base (rocha_caverna + vegetação), assets aprovados do Drive. A caminhabilidade
## usa o canal alfa de verdade da rocha (pixel a pixel — CLAUDE.md: "referencie sempre
## por asset aprovado", nada de polígono desenhado à mão por cima de um sprite real).
## Fundo_Atmosfera fica de fora: as duas versões (dia/noite) estão marcadas REVISAR
## ("fundido com o mar") no Drive, ainda não é asset aprovado.
##
## Quint de verdade em cima, clicável: toca na rocha e ele caminha até lá (FSM muda
## pra WALKING e volta pra IDLE ao chegar). Toque fora da rocha (mar/céu) não faz nada.

const QUINT_SCENE := preload("res://scenes/quint.tscn")
const CENARIO_DIR := "res://art/cenario/"
const ALTURA_ROCHA_MUNDO := 975.0  # escala de composição — não é regra de bíblia,
                                     # só o tamanho que cabe bem no viewport do HUD.
const LIMIAR_ALFA_CAMINHAVEL := 0.1

@onready var _camera: Camera2D = $Camera2D
@onready var _mundo_root: Node2D = $MundoRoot
@onready var _sprite_mar: Sprite2D = $TerrenoReal/Mar
@onready var _sprite_rocha: Sprite2D = $TerrenoReal/Rocha
@onready var _sprite_vegetacao: Sprite2D = $TerrenoReal/Vegetacao
@onready var _debug_label: Label = $HudLayer/DebugLabel
@onready var _botao_dormir: Button = $HudLayer/BotaoDormir
@onready var _botao_comer: Button = $HudLayer/BotaoComer
@onready var _botao_latrina: Button = $HudLayer/BotaoLatrina
@onready var _botao_parar: Button = $HudLayer/BotaoParar

var _quint: Node2D
var _imagem_rocha: Image


func _ready() -> void:
	_posicionar_terreno_real()

	_quint = QUINT_SCENE.instantiate()
	_quint.position = Vector2(0.0, -100.0)  # em cima da rocha, boca da caverna logo abaixo
	_mundo_root.add_child(_quint)

	_camera.position = Vector2.ZERO
	_camera.zoom = Vector2.ONE
	_camera.make_current()

	_botao_dormir.pressed.connect(func(): Quint.mudar_estado(Quint.Estado.SLEEPING))
	_botao_comer.pressed.connect(func(): Quint.mudar_estado(Quint.Estado.EATING))
	_botao_latrina.pressed.connect(func(): Quint.mudar_estado(Quint.Estado.USING_LATRINE))
	_botao_parar.pressed.connect(_on_parar_pressed)

	Tempo.tick.connect(_atualizar_debug)
	_atualizar_debug()


## Mar + Ilha_Base — três PNGs aprovados, todos no mesmo canvas 1877x2500, alinhados
## entre si pelo próprio pipeline de arte (mesma origem/escala pros três, sem precisar
## de offset por imagem).
func _posicionar_terreno_real() -> void:
	var tex_rocha: Texture2D = load(CENARIO_DIR + "ilha_base_rocha_caverna.png")
	_imagem_rocha = tex_rocha.get_image()
	var usado := _imagem_rocha.get_used_rect()
	var escala: float = ALTURA_ROCHA_MUNDO / float(usado.size.y)

	# Pé da formação (centro-x, base-y do retângulo não-transparente de verdade)
	# perto do centro da tela, com folga pro HUD no topo.
	var pes_canvas := Vector2(usado.position.x + usado.size.x / 2.0, usado.position.y + usado.size.y)
	var alvo_mundo := Vector2(0.0, 420.0)
	var origem := alvo_mundo - pes_canvas * escala

	for sprite in [_sprite_mar, _sprite_rocha, _sprite_vegetacao]:
		sprite.scale = Vector2.ONE * escala
		sprite.position = origem
	_sprite_mar.texture = load(CENARIO_DIR + "mar_frente_alpha.png")
	_sprite_rocha.texture = tex_rocha
	_sprite_vegetacao.texture = load(CENARIO_DIR + "ilha_base_vegetacao.png")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().gui_get_hovered_control() == null:
			_tentar_andar_ate(event.position)


func _tentar_andar_ate(pos_tela: Vector2) -> void:
	var pos_mundo := _tela_para_mundo(pos_tela)
	if _sobre_rocha(pos_mundo):
		_quint.mover_para(pos_mundo)


## Pixel a pixel contra o alfa de verdade da rocha (mundo -> espaço local do sprite,
## já descontando escala/posição) — a boca da caverna é opaca na arte (conferido:
## alfa ~251/255, não é um buraco transparente), então caminha normalmente por cima.
func _sobre_rocha(pos_mundo: Vector2) -> bool:
	var local: Vector2 = (pos_mundo - _sprite_rocha.position) / _sprite_rocha.scale
	if local.x < 0.0 or local.y < 0.0 or local.x >= _imagem_rocha.get_width() or local.y >= _imagem_rocha.get_height():
		return false
	return _imagem_rocha.get_pixel(int(local.x), int(local.y)).a > LIMIAR_ALFA_CAMINHAVEL


func _tela_para_mundo(pos_tela: Vector2) -> Vector2:
	var centro := get_viewport().get_visible_rect().size / 2.0
	return _camera.position + (pos_tela - centro) / _camera.zoom


## "Parar" resolve a necessidade que motivou o estado atual antes de voltar a IDLE —
## sem isso, sair de EATING/USING_LATRINE não credita a recuperação correspondente.
func _on_parar_pressed() -> void:
	if Quint.estado == Quint.Estado.USING_LATRINE:
		Quint.resolver_latrina()
	Quint.mudar_estado(Quint.Estado.IDLE)


func _atualizar_debug() -> void:
	var lxp := Economia.libras_xelins_pence()
	var nomes_estado := {
		Quint.Estado.IDLE: "ocioso", Quint.Estado.WALKING: "andando",
		Quint.Estado.SLEEPING: "dormindo", Quint.Estado.EATING: "comendo",
		Quint.Estado.USING_LATRINE: "na latrina",
	}
	_debug_label.text = "dia %d (%s) · %s · fase %s\nQuint: %s (toque na rocha pra andar)\nenergia %.0f%% · fome %.0f%% · latrina %.0f%%\n£%d s.%d d.%d\nquerosene %.1fL · kit %.1f · peixe %.1fkg" % [
		Tempo.dia_geral, Tempo.dia_semana(), _visitante_texto(), Tempo.nome_fase(Tempo.fase_atual),
		nomes_estado.get(Quint.estado, "?"),
		Quint.energia, Quint.fome, Quint.latrina,
		lxp["libras"], lxp["xelins"], lxp["pence"],
		Economia.estoques["querosene_litros"], Economia.estoques["kit_sobrevivencia"], Economia.estoques["peixes_kg"],
	]


func _visitante_texto() -> String:
	var v = Tempo.visitante_de_hoje()
	return v if v != null else "sem visita"
