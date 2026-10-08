class_name Dialogo
extends Control
## Diálogo da história (decisão 32), em cena: a tela escurece, o personagem que
## fala entra deslizando de lado em corpo inteiro (Assets, variante "corpo"),
## ocupando quase toda a tela, e na sequência a caixa com nome e fala aparece no
## centro, por cima dele. Quando outro personagem fala, o anterior sai e o novo
## entra. Sem a arte (ou falas do sistema), só a caixa. Tocar avança (ou, no meio
## da entrada, completa a animação). Ações de tutorial no meio da cena saem pelo
## sinal `acao` quando a fala chega nelas; durante um destaque o personagem fica
## translúcido para o elemento destacado aparecer. Cenas pedidas durante outra
## entram na fila. Ações próprias do diálogo: [ESCURO] (a tela fica preta até [CLARO]
## ou o fim da sequência) e [PAUSA] (um silêncio sem caixa). Falas aceitam variáveis do
## jogo ({pista}, {saldo}...: Historia.variaveis) e, na primeira vez que alguém
## fala, o nome vem com o papel (personagens.json → papel).

signal acao(nome: String)
## Cena terminada (para a principal encadear a próxima e salvar).
signal terminou(c: Dictionary)

## Apresentação, não balanceamento.
const ENTRADA_S := 0.35
const CAIXA_ATRASO_S := 0.2
const CAIXA_S := 0.22
const ALTURA_CORPO := 0.86  # fração da altura da tela
const PAUSA_S := 1.6

var historia: Historia
var _fila: Array = []
var _cena: Dictionary = {}
var _i := 0
var _fundo: ColorRect
var _corpo: TextureRect
var _quem := ""
var _caixa: PanelContainer
var _nome: Label
var _texto: Label
var _tween: Tween
var _animando := false
var _lado := 1.0  # de que lado o próximo personagem entra (alterna)
var _translucido := false  # depois de um destaque, até o fim da cena
var _escuro := false  # [ESCURO] vale até [CLARO] ou o fim da sequência de cenas


func _init(historia_: Historia) -> void:
	historia = historia_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.62)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.gui_input.connect(_toque)
	add_child(_fundo)
	_corpo = TextureRect.new()
	_corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_corpo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corpo)
	_caixa = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	sb.border_color = Aba.COR_DESTAQUE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	_caixa.add_theme_stylebox_override("panel", sb)
	_caixa.gui_input.connect(_toque)
	# No centro (um pouco abaixo do meio), crescendo para cima e para baixo.
	_caixa.anchor_left = 0.0
	_caixa.anchor_right = 1.0
	_caixa.anchor_top = 0.58
	_caixa.anchor_bottom = 0.58
	_caixa.offset_left = 24
	_caixa.offset_right = -24
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_caixa)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 8)
	_caixa.add_child(v)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 26)
	_nome.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(_nome)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 32)
	v.add_child(_texto)
	var rodape := HBoxContainer.new()
	v.add_child(rodape)
	var pular := Button.new()
	pular.text = "Pular ›"
	pular.flat = true
	pular.add_theme_font_size_override("font_size", 20)
	pular.pressed.connect(pular_cena)
	rodape.add_child(pular)
	var dica := Label.new()
	dica.text = "toque para continuar ›"
	dica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dica.add_theme_font_size_override("font_size", 18)
	dica.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	rodape.add_child(dica)
	visible = false


func ocupado() -> bool:
	return not _cena.is_empty()


func enfileirar(c: Dictionary) -> void:
	if c.is_empty() or (_cena.get("id") == c["id"]) or _fila.any(func(x): return x["id"] == c["id"]):
		return
	_fila.append(c)
	if _cena.is_empty():
		_proxima()


func _proxima() -> void:
	if _fila.is_empty():
		_cena = {}
		_quem = ""
		_escuro = false
		visible = false
		return
	_cena = _fila.pop_front()
	_i = 0
	_translucido = false
	visible = true
	_fundo.visible = true
	_fundo.color.a = 1.0 if _escuro else 0.62
	_caixa.visible = true
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_mostrar()


## Mostra a fala atual; ações seguidas executam antes de parar na próxima fala.
func _mostrar() -> void:
	var falas: Array = _cena["falas"]
	while _i < falas.size() and falas[_i].has("acao"):
		var nome_acao := String(falas[_i]["acao"])
		_i += 1
		match nome_acao:
			"ESCURO":
				# Tela preta (o acidente): segue no escuro até [CLARO].
				_escuro = true
				_corpo.visible = false
				_quem = ""
				create_tween().tween_property(_fundo, "color:a", 1.0, 0.8)
				continue
			"CLARO":
				_escuro = false
				create_tween().tween_property(_fundo, "color:a", 0.62, 0.8)
				continue
			"PAUSA":
				# Silêncio: nada na tela por um instante, depois segue.
				_caixa.visible = false
				_animando = true
				if _tween != null:
					_tween.kill()
				_tween = create_tween()
				_tween.tween_interval(PAUSA_S)
				_tween.tween_callback(func():
					_caixa.visible = true
					_animando = false
					_mostrar())
				return
		# Destaque: o personagem fica translúcido para o elemento aparecer.
		if nome_acao.begins_with("HIGHLIGHT_"):
			_translucido = true
			_corpo.modulate.a = 0.25
		acao.emit(nome_acao)
	if _i >= falas.size():
		_fim()
		return
	var f: Dictionary = falas[_i]
	var quem := String(f["quem"])
	var p := historia.personagem(quem)
	var sistema := quem == "sistema"
	_nome.text = String(p.get("nome", quem))
	# Primeira vez que fala: nome e papel (quem é essa pessoa).
	var flag := "APRESENTADO_" + quem.to_upper()
	if not sistema and String(p.get("papel", "")) != "" and not historia.jogador.flags.has(flag):
		_nome.text += " · " + String(p["papel"])
		historia.jogador.flags[flag] = true
	_nome.visible = not sistema and _nome.text != ""
	_texto.text = String(f["texto"]).format(historia.variaveis(_cena.get("_ctx", {})))
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if sistema else HORIZONTAL_ALIGNMENT_LEFT
	_layout()
	if quem != _quem:
		_entrar(quem, sistema)
	_quem = quem


## Personagem novo: o anterior sai, o novo entra deslizando, depois a caixa.
func _entrar(quem: String, sistema: bool) -> void:
	if _tween != null:
		_tween.kill()
	var tex: Texture2D = null if sistema else _textura(quem)
	var tela := get_viewport_rect().size
	_lado = -_lado
	_corpo.texture = tex
	_corpo.visible = tex != null
	var x_final := _corpo.position.x
	_caixa.modulate.a = 0.0
	_animando = true
	_tween = create_tween()
	if tex != null:
		_corpo.position.x = x_final + _lado * tela.x
		_corpo.modulate.a = 0.25 if _translucido else 1.0
		_tween.tween_property(_corpo, "position:x", x_final, ENTRADA_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(CAIXA_ATRASO_S)
	_tween.tween_property(_caixa, "modulate:a", 1.0, CAIXA_S)
	_tween.tween_callback(func(): _animando = false)


func _textura(quem: String) -> Texture2D:
	return Assets.get_asset(quem, "corpo")


## Corpo centrado embaixo, quase da altura da tela (a caixa vai por âncora).
func _layout() -> void:
	var tela := get_viewport_rect().size
	var h := tela.y * ALTURA_CORPO
	_corpo.size = Vector2(h * 2.0 / 3.0, h)
	_corpo.position = Vector2((tela.x - _corpo.size.x) / 2.0, tela.y - h)


func _toque(ev: InputEvent) -> void:
	var toque: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
			or (ev is InputEventScreenTouch and ev.pressed)
	if toque and not _cena.is_empty():
		accept_event()
		if _animando and _tween != null:
			_tween.custom_step(10.0)  # completa a entrada
			return
		avancar()


## Pula as falas da cena; ações e flags dela acontecem do mesmo jeito.
func pular_cena() -> void:
	if _cena.is_empty():
		return
	var falas: Array = _cena["falas"]
	_i += 1
	while _i < falas.size():
		if falas[_i].has("acao"):
			acao.emit(String(falas[_i]["acao"]))
		_i += 1
	_fim()


func avancar() -> void:
	_i += 1
	_mostrar()


func _fim() -> void:
	var c := _cena
	var proxima := historia.concluir(c)
	terminou.emit(c)
	if not proxima.is_empty():
		_fila.push_front(proxima)
	_quem = ""
	_proxima()
