extends Node2D
## Token visual de Quint. Lê/escreve o estado em cima do autoload `Quint` (FSM +
## necessidades) — este nó só cuida de posição, tween de caminhada e sprite. Usa os
## sprites reais de art/chr/quint_idle_<direcao>_01.png (manual §23.2, um por direção
## NE/NW/SE/SW) quando existem; cai no placeholder geométrico só pra direção que ainda
## não tem asset aprovado (SE está marcado REVISAR no Drive — prótese desenhada
## invertida — não foi sincronizado até ser corrigido).

const VELOCIDADE_PX_SEG := 180.0  # placeholder de engenharia — a bíblia não fixa
                                    # velocidade de deslocamento em px/s, isso não é
                                    # "balanceamento" no sentido do §17.7.
const ART_DIR := "res://art/chr/"
const ALTURA_REFERENCIA := 96.0  # manual §23.2: mesma altura de referência pra todo o elenco

@onready var _visual: Node2D = $Visual
@onready var _corpo: Polygon2D = $Visual/Corpo
@onready var _cabeca: Polygon2D = $Visual/Cabeca
@onready var _sprite: Sprite2D = $Visual/Sprite

var _tween_movimento: Tween
var _tween_balanco: Tween
var _andando := false
var _direcao_atual := "sw"  # única direção aprovada que também serve bem de pose parada


func _ready() -> void:
	_atualizar_sprite_direcao()
	Quint.estado_mudou.connect(_on_estado_mudou)
	_definir_andando(false)


## NE/NW = pra cima da tela (y-), SE/SW = pra baixo (y+); leste/oeste pelo sinal de x.
## Projeção isométrica padrão do resto do projeto (Iso.cell_to_pos): x cresce pra
## direita, y cresce pra baixo.
func _direcao_do_vetor(v: Vector2) -> String:
	var norte := v.y <= 0.0
	var leste := v.x >= 0.0
	if norte:
		return "ne" if leste else "nw"
	return "se" if leste else "sw"


## Troca o sprite pra direção atual. Sem asset aprovado pra essa direção, cai no
## placeholder geométrico (nunca um sprite não aprovado — manual §23.3).
func _atualizar_sprite_direcao() -> void:
	var caminho := "%squint_idle_%s_01.png" % [ART_DIR, _direcao_atual]
	if not ResourceLoader.exists(caminho):
		_sprite.visible = false
		_corpo.visible = true
		_cabeca.visible = true
		return

	var textura: Texture2D = load(caminho)
	_sprite.texture = textura

	# Pivô nos pés (manual §23.2): usa o retângulo de pixels não-transparentes de
	# verdade (get_used_rect), em vez de supor que os pés encostam na borda do
	# canvas — cada pose deixa uma margem de recorte um pouco diferente.
	var img := textura.get_image()
	var usado := img.get_used_rect()
	var escala: float = ALTURA_REFERENCIA / float(usado.size.y)
	_sprite.scale = Vector2.ONE * escala
	var centro_x := usado.position.x + usado.size.x / 2.0
	var pes_y := usado.position.y + usado.size.y
	_sprite.position = Vector2(-centro_x * escala, -pes_y * escala)

	_sprite.visible = true
	_corpo.visible = false
	_cabeca.visible = false


## Caminha em linha reta até `destino` (mundo). Sem pathfinding ainda — a ilha
## placeholder não tem obstáculo nenhum pra desviar; isso chega junto com as
## edificações (ordem de produção do manual: Casa/Latrina/Boathouse antes de rota).
func mover_para(destino: Vector2) -> void:
	if _tween_movimento != null:
		_tween_movimento.kill()

	var delta := destino - position
	if delta.length() > 1.0:
		_direcao_atual = _direcao_do_vetor(delta)
		_atualizar_sprite_direcao()

	Quint.mudar_estado(Quint.Estado.WALKING)
	_definir_andando(true)

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
