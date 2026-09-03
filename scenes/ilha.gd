extends Node2D
## Cena principal. A ilha de Dreadwick em si (o penhasco com farol, casas e caminho —
## bíblia #16.1) ainda não tem asset aprovado no Drive, então é um placeholder
## geométrico (contorno determinístico, sem RNG) — a Caverna Marítima
## (art/cenario/ilha_base_rocha_caverna.png + vegetação + o recorte de mar que vem
## junto dela) É um asset real, mas é um elemento de cenário à parte: fica pequena, no
## fundo da visualização, atrás da ilha (correção do usuário — antes eu tinha esticado
## a caverna pra cobrir a ilha inteira, o que não fazia sentido). Os três PNGs da
## caverna share o mesmo canvas 1877x2500 e continuam colados na mesma escala/posição
## entre si — só o tamanho e o lugar dela na cena mudaram.
##
## Quint de verdade em cima, clicável: toca na ilha e ele caminha até lá (FSM muda pra
## WALKING e volta pra IDLE ao chegar). Toque fora da ilha não faz nada.

const QUINT_SCENE := preload("res://scenes/quint.tscn")
const EDIFICACAO_SCENE := preload("res://scenes/edificacao.tscn")
const CENARIO_DIR := "res://art/cenario/"
const ALTURA_CAVERNA_MUNDO := 260.0  # elemento de fundo pequeno, não a ilha inteira

@onready var _camera: Camera2D = $Camera2D
@onready var _mundo_root: Node2D = $MundoRoot
@onready var _ilha_base: Polygon2D = $IlhaBase
@onready var _sprite_mar: Sprite2D = $TerrenoReal/Mar
@onready var _sprite_rocha: Sprite2D = $TerrenoReal/Rocha
@onready var _sprite_vegetacao: Sprite2D = $TerrenoReal/Vegetacao
@onready var _caminho: Line2D = $Caminho
@onready var _debug_label: Label = $HudLayer/DebugLabel
@onready var _botao_dormir: Button = $HudLayer/BotaoDormir
@onready var _botao_comer: Button = $HudLayer/BotaoComer
@onready var _botao_latrina: Button = $HudLayer/BotaoLatrina
@onready var _botao_parar: Button = $HudLayer/BotaoParar

var _quint: Node2D


func _ready() -> void:
	_ilha_base.polygon = _gerar_contorno_ilha()
	_posicionar_caverna_maritima()
	_instanciar_edificacoes()

	_quint = QUINT_SCENE.instantiate()
	_quint.position = Vector2(0.0, -450.0)  # perto da Casa de Quint, no platô do farol
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


## Contorno fechado e determinístico (sem RNG — não precisa de seed nem save) com
## harmônicos de baixa ordem e amplitude modesta (≤15% do raio-base) pra nunca
## autointerseccionar. Cobre o mesmo intervalo vertical (~-580 a ~580) usado para
## calibrar as edificações em data/edificacoes.json.
func _gerar_contorno_ilha() -> PackedVector2Array:
	var pontos := PackedVector2Array()
	var n := 20
	for i in range(n):
		var ang := TAU * i / float(n)
		var raio_x := 340.0 + 40.0 * cos(ang * 3.0)
		var raio_y := 520.0 + 58.0 * sin(ang * 2.0)
		pontos.append(Vector2(cos(ang) * raio_x, sin(ang) * raio_y))
	return pontos


## Mar + Ilha_Base (rocha_caverna, vegetação) — três PNGs aprovados que representam a
## Caverna Marítima, não a ilha inteira. Mantêm a mesma escala/posição entre si (o
## alinhamento que já vinha correto do pipeline de arte), só numa escala pequena,
## perto da base da ilha, atrás do contorno placeholder.
func _posicionar_caverna_maritima() -> void:
	var tex_rocha: Texture2D = load(CENARIO_DIR + "ilha_base_rocha_caverna.png")
	var usado := tex_rocha.get_image().get_used_rect()
	var escala: float = ALTURA_CAVERNA_MUNDO / float(usado.size.y)

	var pes_canvas := Vector2(usado.position.x + usado.size.x / 2.0, usado.position.y + usado.size.y)
	var alvo_mundo := Vector2(60.0, 500.0)  # perto da borda sul do contorno (~y 520-527 aqui) —
	                                          # parte da caverna some atrás da ilha, parte
	                                          # sai por baixo, visível contra o mar
	var origem := alvo_mundo - pes_canvas * escala

	for sprite in [_sprite_mar, _sprite_rocha, _sprite_vegetacao]:
		sprite.scale = Vector2.ONE * escala
		sprite.position = origem
	_sprite_mar.texture = load(CENARIO_DIR + "mar_frente_alpha.png")
	_sprite_rocha.texture = tex_rocha
	_sprite_vegetacao.texture = load(CENARIO_DIR + "ilha_base_vegetacao.png")


## Um Edificacao por entrada de data/edificacoes.json, na posição lida da referência de
## composição (ver _status do JSON — placeholder de leiaute, não asset aprovado ainda).
## "caverna_maritima" não ganha marcador: já é o cenário real posicionado acima — só
## entra no traçado do caminho abaixo.
func _instanciar_edificacoes() -> void:
	var cfg := Dados.edificacoes()
	var por_id: Dictionary = {}
	for def in cfg.get("edificacoes", []):
		var pos: Array = def["posicao"]
		por_id[def["id"]] = Vector2(pos[0], pos[1])
		if def["id"] == "caverna_maritima":
			continue
		var no := EDIFICACAO_SCENE.instantiate()
		no.position = Vector2(pos[0], pos[1])
		_mundo_root.add_child(no)
		no.configurar(def["id"], def["nome"])

	var pontos := PackedVector2Array()
	for id in cfg.get("ordem_caminho", []):
		if por_id.has(id):
			pontos.append(por_id[id])
	_caminho.points = pontos


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport().gui_get_hovered_control() == null:
			_tentar_andar_ate(event.position)


func _tentar_andar_ate(pos_tela: Vector2) -> void:
	var pos_mundo := _tela_para_mundo(pos_tela)
	var pos_local := _ilha_base.to_local(pos_mundo)
	if Geometry2D.is_point_in_polygon(pos_local, _ilha_base.polygon):
		_quint.mover_para(pos_mundo)


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
	_debug_label.text = "dia %d (%s) · %s · fase %s\nQuint: %s (toque na ilha pra andar)\nenergia %.0f%% · fome %.0f%% · latrina %.0f%%\n£%d s.%d d.%d\nquerosene %.1fL · kit %.1f · peixe %.1fkg" % [
		Tempo.dia_geral, Tempo.dia_semana(), _visitante_texto(), Tempo.nome_fase(Tempo.fase_atual),
		nomes_estado.get(Quint.estado, "?"),
		Quint.energia, Quint.fome, Quint.latrina,
		lxp["libras"], lxp["xelins"], lxp["pence"],
		Economia.estoques["querosene_litros"], Economia.estoques["kit_sobrevivencia"], Economia.estoques["peixes_kg"],
	]


func _visitante_texto() -> String:
	var v = Tempo.visitante_de_hoje()
	return v if v != null else "sem visita"
