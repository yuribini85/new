class_name VoltaAbertura
extends Control
## Abertura do jogo (roteiro "Second Driver — Abertura"): tela preta, o motor
## antes da imagem, a pista aparece devagar e o carro do Adrian faz uma volta
## sozinho, com a mesma câmera das corridas (diretor AUTO), sem HUD, rivais nem
## menus. Cruza a linha, a câmera fica nele, a imagem escurece, o motor some,
## uma pausa curta e acaba (a cena 1 começa). A volta é simulada como qualquer
## corrida (Simulacao); aqui só se reproduz. Pista: historia.json →
## adrian.pista_volta. Tempos: apresentação, não balanceamento.

signal terminou

const MOTOR_ANTES_S := 1.4  # o som aparece antes da imagem
const REVELAR_S := 3.0
const FICA_S := 2.5  # na câmera depois da linha
const ESCURECER_S := 1.8
const PAUSA_S := 0.8

var _3d: Corrida3D
var _fonte: CorridaVisual
var _diretor := DiretorCamera.new()
var _sons: Sons
var _preto: ColorRect
var _pista: Pista
var _t := -MOTOR_ANTES_S
var _duracao := 0.0
var _s_antes := 0.0
var _acabou := false


func _init(dados: Node, jogador: Node) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var carro: Carro = jogador.garagem.carro(jogador.carro_ativo)
	_pista = dados.pista(String(dados.historia().get("adrian", {}).get("pista_volta", "")))
	if carro == null or _pista == null:
		_acabou = true
		return
	var r := Simulacao.correr(_pista, [{"id": "jogador", "atributos": carro.atributos_efetivos("seco"),
			"piloto": dados.piloto(dados.carreira()["piloto_jogador"])}], 1, dados.simulacao(), hash("abertura"))
	_duracao = float(r["duracao"])
	var cor := CarroBloco.cor_do_carro(carro)
	_fonte = CorridaVisual.new()
	_fonte.visible = false
	add_child(_fonte)
	_fonte.mostrar(_pista, r, {"jogador": cor})
	_3d = Corrida3D.new()
	_3d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_3d.sem_rotulos = true
	add_child(_3d)
	_3d.mostrar(_pista, _fonte, {"jogador": carro.base}, {"jogador": cor})
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preto)
	_sons = Sons.new()
	add_child(_sons)
	var pular := Button.new()
	Tipografia.acao_secundaria(pular, "Pular ›", Color(0.93, 0.92, 0.88, 0.7), 30, 80)
	pular.custom_minimum_size.x = 150
	pular.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pular.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pular.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pular.offset_right = -16
	pular.offset_bottom = -16
	pular.pressed.connect(_terminar)
	add_child(pular)


func _process(delta: float) -> void:
	if _acabou:
		_terminar()
		return
	_t += delta
	var depois := _t - _duracao  # > 0: já cruzou a linha
	var saida := clampf((depois - FICA_S) / ESCURECER_S, 0.0, 1.0)
	# Som: entra antes da imagem e some com ela.
	var entrada := clampf((_t + MOTOR_ANTES_S) / MOTOR_ANTES_S, 0.0, 1.0)
	_sons.volume_motor(entrada * (1.0 - saida))
	if _t < 0.0:
		_sons.motor(true, 0.0)
		return
	_fonte.tempo = _t
	var plano := _diretor.atualizar(_fonte, _pista.comprimento, _pista.comprimento, 1)
	_3d.visao_geral = plano["geral"]
	_3d.foco = "jogador"
	_3d.enquadrar_com = ""
	if depois > 0.0:
		_3d.chegada = minf(depois / 3.0, 1.0)
	_3d.atualizar(delta)
	var s := _fonte.distancia("jogador")
	_sons.motor(saida < 1.0, (s - _s_antes) / maxf(delta, 1e-3))
	_s_antes = s
	_preto.color.a = maxf(1.0 - smoothstep(0.0, REVELAR_S, _t), saida)
	if depois > FICA_S + ESCURECER_S + PAUSA_S:
		_terminar()


func _terminar() -> void:
	if is_queued_for_deletion():
		return
	if _sons != null:
		_sons.motor(false)
	terminou.emit()
	queue_free()
