extends Node2D
## Token visual de Quint. Lê/escreve o estado em cima do autoload `Quint` (FSM +
## necessidades) — este nó só cuida de posição, tween de caminhada e (quando existir)
## sprite real. CLAUDE.md: "não gere arte" — placeholder geométrico até existir asset
## aprovado. Pivô nos pés (manual de assets §23.2 / bíblia #23.2): a origem do nó fica
## exatamente onde os pés tocam o chão.

const VELOCIDADE_PX_SEG := 180.0  # placeholder de engenharia — a bíblia não fixa
                                    # velocidade de deslocamento em px/s, isso não é
                                    # "balanceamento" no sentido do §17.7.
const ART_DIR := "res://art/chr/"

@onready var _visual: Node2D = $Visual
@onready var _corpo: Polygon2D = $Visual/Corpo
@onready var _cabeca: Polygon2D = $Visual/Cabeca
@onready var _sprite: Sprite2D = $Visual/Sprite

var _tween_movimento: Tween
var _tween_balanco: Tween
var _andando := false


func _ready() -> void:
	_carregar_arte_se_existir()
	Quint.estado_mudou.connect(_on_estado_mudou)
	_definir_andando(false)


## quint_idle.png único por enquanto (manual §23.3 pede sprite_mundo/ direcional
## completo — NE/NW/SE/SW, personagem_acao_direcao_frame — mas nenhum asset desses
## foi sincronizado no repositório ainda; isso troca só o corpo estático, sem ciclo de
## caminhada real, até existir sprite_mundo aprovado).
func _carregar_arte_se_existir() -> void:
	var caminho := "%squint_idle.png" % ART_DIR
	if not ResourceLoader.exists(caminho):
		return
	var textura: Texture2D = load(caminho)
	_sprite.texture = textura
	const ALTURA_REFERENCIA := 96.0  # manual §23.2: mesma altura de referência pra todo o elenco
	var escala: float = ALTURA_REFERENCIA / textura.get_height()
	_sprite.scale = Vector2.ONE * escala
	_sprite.position = Vector2(-textura.get_width() * escala / 2.0, -textura.get_height() * escala)
	_sprite.visible = true
	_corpo.visible = false
	_cabeca.visible = false


## Caminha em linha reta até `destino` (mundo). Sem pathfinding ainda — a ilha
## placeholder não tem obstáculo nenhum pra desviar; isso chega junto com as
## edificações (ordem de produção do manual: Casa/Latrina/Boathouse antes de rota).
func mover_para(destino: Vector2) -> void:
	if _tween_movimento != null:
		_tween_movimento.kill()

	Quint.mudar_estado(Quint.Estado.WALKING)
	_definir_andando(true)
	if destino.x != position.x:
		_visual.scale.x = absf(_visual.scale.x) * signf(destino.x - position.x)

	var distancia := position.distance_to(destino)
	var duracao := distancia / VELOCIDADE_PX_SEG
	_tween_movimento = create_tween()
	_tween_movimento.tween_property(self, "position", destino, duracao)
	_tween_movimento.tween_callback(_on_chegou)


func _on_chegou() -> void:
	_definir_andando(false)
	Quint.mudar_estado(Quint.Estado.IDLE)


## Reage a mudanças de estado que não passaram por mover_para (ex.: HUD de debug
## mandando dormir/comer/latrina diretamente) — mantém o balanço de "parado" nesses
## casos, já que não há caminhada envolvida.
func _on_estado_mudou(novo_estado: Quint.Estado) -> void:
	if novo_estado != Quint.Estado.WALKING and _andando:
		_definir_andando(false)


func _definir_andando(andando: bool) -> void:
	if _andando == andando and _tween_balanco != null:
		return
	_andando = andando
	if _tween_balanco != null:
		_tween_balanco.kill()

	_tween_balanco = create_tween().set_loops()
	if andando:
		_tween_balanco.tween_property(_visual, "position:y", -4.0, 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.parallel().tween_property(_visual, "scale:y", 0.9, 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.chain().tween_property(_visual, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
		_tween_balanco.parallel().tween_property(_visual, "scale:y", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	else:
		_tween_balanco.tween_property(_visual, "position:y", -2.0, 0.9).set_trans(Tween.TRANS_SINE)
		_tween_balanco.tween_property(_visual, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
