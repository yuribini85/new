class_name RolagemToque
extends ScrollContainer
## Lista rolável pelo dedo, para celular: a base das abas (Aba) e o painel da
## Sobreposicao. O arrasto do próprio ScrollContainer só começa em área vazia
## (os botões ficam com o toque); a rolagem por arrasto é a de _input, abaixo.


func _init() -> void:
	scroll_deadzone = 100000


# O dedo pode começar em qualquer ponto da lista, até em cima de um botão: depois
# de LIMIAR_ARRASTO px o toque vira rolagem, e o botão não é
# acionado (a soltura vai para fora da tela). Ao soltar, a lista ainda desliza
# um pouco (inércia). Arrasto de lado rola a lista horizontal sob o dedo
# (miniaturas, filtros); sliders seguem com o próprio arrasto. Apresentação,
# não balanceamento.
const LIMIAR_ARRASTO := 14.0
const ATRITO := 4.0  # por segundo: quanto a inércia perde
var _toque := false
var _arrastando := false
var _inicio := Vector2.ZERO
var _ultimo := Vector2.ZERO
var _ultimo_t := 0.0
var _velocidade := 0.0
## O que o arrasto rola: esta lista (vertical) ou uma lista de lado dentro dela.
var _alvo: ScrollContainer
var _horizontal := false


const FORA := Vector2(-10000, -10000)


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree():
		_toque = false
		_arrastando = false
		return
	if e is InputEventMouse and e.position.x < FORA.x / 2.0:
		return  # os eventos "fora da tela" que esta rolagem manda passam direto
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_toque = get_global_rect().has_point(e.position)
			_arrastando = false
			_inicio = e.position
			_ultimo = e.position
			_ultimo_t = Time.get_ticks_msec() / 1000.0
			_velocidade = 0.0
		elif _toque:
			_toque = false
			if _arrastando:
				_arrastando = false
				get_viewport().set_input_as_handled()
				# Solta fora da tela: o botão onde o dedo começou não é acionado.
				var fora: InputEventMouseButton = e.duplicate()
				fora.position = FORA
				fora.global_position = FORA
				Input.parse_input_event(fora)
	elif e is InputEventMouseMotion and _toque:
		var d: Vector2 = e.position - _inicio
		if not _arrastando:
			if maxf(absf(d.x), absf(d.y)) < LIMIAR_ARRASTO:
				return
			var sob := get_viewport().gui_get_hovered_control()
			if sob != null and sob != self and not is_ancestor_of(sob):
				_toque = false  # o dedo está em outra camada (diálogo, barra)
				return
			if sob is Range:
				_toque = false  # slider segue com o próprio arrasto
				return
			_horizontal = absf(d.x) > absf(d.y)
			_alvo = _lista_de_lado(sob) if _horizontal else self
			if _alvo == null:
				_toque = false  # de lado, fora de uma lista que rola de lado
				return
			_arrastando = true
			_ultimo = e.position
			# O botão sob o dedo só desiste do toque vendo o dedo sair dele.
			var saiu: InputEventMouseMotion = e.duplicate()
			saiu.position = FORA
			saiu.global_position = FORA
			Input.parse_input_event(saiu)
		var agora := Time.get_ticks_msec() / 1000.0
		var dv: float = (e.position.x - _ultimo.x) if _horizontal else (e.position.y - _ultimo.y)
		_rolar(dv)
		if agora > _ultimo_t:
			_velocidade = lerpf(_velocidade, dv / (agora - _ultimo_t), 0.5)
		_ultimo = e.position
		_ultimo_t = agora
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _toque or absf(_velocidade) < 20.0 or not is_instance_valid(_alvo):
		return
	_rolar(_velocidade * delta)
	_velocidade *= exp(-ATRITO * delta)


func _rolar(d: float) -> void:
	if _alvo == self and vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		return  # tela sem rolagem (Corrida)
	if _horizontal:
		_alvo.scroll_horizontal -= int(round(d))
	else:
		_alvo.scroll_vertical -= int(round(d))


## Lista que rola de lado contendo o controle (miniaturas, filtros), ou null.
func _lista_de_lado(c: Node) -> ScrollContainer:
	var n := c
	while n != null and n != self:
		if n is ScrollContainer and n.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return n
		n = n.get_parent()
	return null
