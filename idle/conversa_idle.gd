class_name ConversaIdle
extends Control
## Conversa de um passo da escada do Chrome Racing Team (idle.json →
## desbloqueios): a tela escurece, o personagem do acervo (arte de corpo
## inteiro, arte/personagens/corpo/) entra deslizando pela esquerda e a caixa
## embaixo traz nome, papel e a fala sendo digitada. Tocar completa o texto. O
## passo de graça fecha com um botão; o que tem custo oferece COMPRAR e AGORA NÃO.

signal fechou(aceitou: bool)

const LETRAS_POR_S := 55.0
const ENTRADA_S := 0.35

var _d: Dictionary
var _estado: IdleEstado
var _fala: Label
var _botoes: HBoxContainer
var _pagar: Button
var _corpo: TextureRect
var _caixa: PanelContainer


func _init(d: Dictionary, estado: IdleEstado) -> void:
	_d = d
	_estado = estado
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var quem: Dictionary = d.get("quem", {})
	var caminho := "res://arte/personagens/corpo/%s.webp" % String(quem.get("id", ""))
	_corpo = TextureRect.new()
	_corpo.texture = load(caminho) if ResourceLoader.exists(caminho) else null
	_corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_corpo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	_corpo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_corpo.anchor_top = 0.12
	_corpo.anchor_bottom = 0.86
	_corpo.anchor_right = 0.8
	_corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corpo)
	_caixa = PanelContainer.new()
	_caixa.add_theme_stylebox_override("panel", IdleUI.caixa(Color(IdleUI.COR_CARTAO, 0.97), 18, 18, IdleUI.COR_OURO, 2))
	_caixa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caixa.offset_left = 16
	_caixa.offset_right = -16
	_caixa.offset_bottom = -16 - AreaSegura.base(720.0)
	_caixa.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_caixa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_caixa.add_child(v)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	v.add_child(cab)
	IdleUI.rotulo(String(quem.get("nome", "")).to_upper(), 26, IdleUI.COR_OURO, cab, "display")
	var papel := IdleUI.rotulo(String(quem.get("papel", "")), 18, IdleUI.COR_SECUNDARIA, cab)
	papel.size_flags_vertical = Control.SIZE_SHRINK_END
	_fala = IdleUI.rotulo(String(d.get("fala", "")), 24, IdleUI.COR_TEXTO, v, "regular")
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fala.custom_minimum_size = Vector2(0, 96)
	_fala.visible_ratio = 0.0
	_botoes = HBoxContainer.new()
	_botoes.add_theme_constant_override("separation", 12)
	_botoes.modulate.a = 0.0
	v.add_child(_botoes)
	var custo := float(d.get("custo", 0.0))
	if custo > 0.0:
		var depois := IdleUI.botao("AGORA NÃO", IdleUI.COR_CROMO, 24, 72, _botoes)
		depois.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		depois.pressed.connect(_fechar.bind(false))
		_pagar = IdleUI.botao("COMPRAR $" + IdleUI.curto(custo), IdleUI.COR_OURO, 26, 72, _botoes)
		_pagar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pagar.size_flags_stretch_ratio = 1.6
		_pagar.pressed.connect(_fechar.bind(true))
	else:
		var ok := IdleUI.botao(String(d.get("botao", "ENTENDI")), IdleUI.COR_OURO, 26, 72, _botoes)
		ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok.pressed.connect(_fechar.bind(true))


func _ready() -> void:
	var instantaneo := Preferencias.reduzir_animacoes
	if not instantaneo:
		# Entra deslizando da esquerda (pelos offsets: as âncoras seguram o tamanho).
		var w := get_viewport_rect().size.x * 0.5
		_corpo.offset_left = -w
		_corpo.offset_right = -w
		_corpo.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_corpo, "offset_left", 0.0, ENTRADA_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_corpo, "offset_right", 0.0, ENTRADA_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_corpo, "modulate:a", 1.0, ENTRADA_S * 0.6)
	var letras := _fala.text.length()
	var digitar := create_tween()
	digitar.tween_interval(ENTRADA_S * 0.6)
	digitar.tween_property(_fala, "visible_ratio", 1.0, 0.0 if instantaneo else letras / LETRAS_POR_S)
	digitar.tween_callback(_mostrar_botoes)
	Sons.tocar_ui(self, "toque", -8.0)


func _process(_delta: float) -> void:
	if _pagar != null:
		var custo := float(_d.get("custo", 0.0))
		_pagar.disabled = _estado.dinheiro < custo
		_pagar.text = ("COMPRAR $" + IdleUI.curto(custo)) if not _pagar.disabled \
				else "FALTAM $" + IdleUI.curto(custo - _estado.dinheiro)


func _mostrar_botoes() -> void:
	_fala.visible_ratio = 1.0
	if _botoes.modulate.a < 1.0:
		create_tween().tween_property(_botoes, "modulate:a", 1.0, 0.15)


func _gui_input(e: InputEvent) -> void:
	var toque: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and e.pressed)
	if toque and _fala.visible_ratio < 1.0:
		_mostrar_botoes()
		accept_event()


func _fechar(aceitou: bool) -> void:
	if _fala.visible_ratio < 1.0:
		_mostrar_botoes()
		return
	fechou.emit(aceitou)
	queue_free()
