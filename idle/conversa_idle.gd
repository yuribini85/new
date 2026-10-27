class_name ConversaIdle
extends Control
## Conversa de um passo da escada do The Fastfather (idle.json →
## desbloqueios): a tela escurece, o personagem do acervo (arte de corpo
## inteiro, arte/personagens/corpo/) entra deslizando pela esquerda e embaixo
## vem a faixa da fala: tarja vinho com o nome, tarja creme com o papel e o
## painel com a fala sendo digitada. Tocar completa o texto. O
## passo de graça fecha com um botão; o que tem custo oferece COMPRAR e AGORA NÃO.

signal fechou(aceitou: bool)

const LETRAS_POR_S := 55.0
const ENTRADA_S := 0.35
## Voz de conversa (docs/idle/sonorizacao.md, 3.6): um "blip" a cada
## LETRAS_POR_BLIP letras digitadas, no tom de quem fala (grave a agudo).
const LETRAS_POR_BLIP := 3
const VOZES := {"mara_hayes": 0.8, "bianca_sterling": 1.15, "harold_brandt": 0.7, "theo_lane": 0.9,
		"jade_ryker": 1.2, "roxy_vega": 1.3, "rico_salas": 0.85, "edgar_halloway": 0.6,
		"nora_lindqvist": 1.25, "kenji_arata": 1.0, "dex_kane": 0.72, "sal_moretti": 0.62, "walt_pruitt": 1.1,
		"chefao": 0.6, "sobrinho": 1.15}
var _letras_faladas := 0
const VERMELHO := Color("8e2a26")  # vinho da época (docs/idle/conversao_mafia.md)

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
	var terco := VBoxContainer.new()
	terco.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	terco.offset_bottom = -AreaSegura.base(720.0)
	terco.grow_vertical = Control.GROW_DIRECTION_BEGIN
	terco.add_theme_constant_override("separation", 0)
	add_child(terco)
	# Capítulo novo da história: uma tarja creme acima do nome.
	if d.has("capitulo"):
		var cap := PanelContainer.new()
		cap.add_theme_stylebox_override("panel", IdleUI.caixa(Color("eadfc4"), 0, 8))
		cap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		terco.add_child(cap)
		IdleUI.rotulo("CAPÍTULO " + String(d["capitulo"]).to_upper(), 20, Color("15120e"), cap, "deco")
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 0)
	terco.add_child(cab)
	var tarja := PanelContainer.new()
	tarja.add_theme_stylebox_override("panel", IdleUI.caixa(VERMELHO, 0, 10))
	cab.add_child(tarja)
	IdleUI.rotulo(String(quem.get("nome", "")).to_upper(), 28, Color.WHITE, tarja, "display")
	var papel_caixa := PanelContainer.new()
	papel_caixa.add_theme_stylebox_override("panel", IdleUI.caixa(Color("eef0f3"), 0, 8))
	papel_caixa.size_flags_vertical = Control.SIZE_SHRINK_END
	cab.add_child(papel_caixa)
	IdleUI.rotulo(String(quem.get("papel", "")), 18, Color("111418"), papel_caixa)
	_caixa = PanelContainer.new()
	var painel := IdleUI.caixa(Color(IdleUI.COR_CARTAO, 0.97), 0, 18)
	painel.border_width_top = 4
	painel.border_color = VERMELHO
	_caixa.add_theme_stylebox_override("panel", painel)
	terco.add_child(_caixa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_caixa.add_child(v)
	_fala = IdleUI.rotulo(String(d.get("fala", "")), 26, IdleUI.COR_TEXTO, v, "fala")  # a mesma letra dos balões
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
	_falar()
	if _pagar != null:
		var custo := float(_d.get("custo", 0.0))
		_pagar.disabled = _estado.dinheiro < custo
		_pagar.text = ("COMPRAR $" + IdleUI.curto(custo)) if not _pagar.disabled \
				else "FALTAM $" + IdleUI.curto(custo - _estado.dinheiro)


func _falar() -> void:
	var visiveis := int(_fala.visible_ratio * _fala.text.length())
	if _fala.visible_ratio >= 1.0 or visiveis < _letras_faladas + LETRAS_POR_BLIP:
		return
	_letras_faladas = visiveis
	var letra := _fala.text.substr(maxi(visiveis - 1, 0), 1)
	if letra.strip_edges() == "" or letra in ".,!?":
		return
	var tom := float(VOZES.get(String(_d.get("quem", {}).get("id", "")), 1.0))
	Sons.tocar_ui(self, "voz", -14.0, tom * randf_range(0.94, 1.06), false)


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
