class_name Dialogo
extends Control
## Caixa de diálogo da história (decisão 32), embaixo da tela: retrato
## (Assets; sem o arquivo, quadrado na cor do personagem com as iniciais), nome
## e texto. Tocar avança. Ações de tutorial no meio da cena saem
## pelo sinal `acao` quando a fala chega nelas. Cena que bloqueia escurece a
## tela e segura o toque; as outras deixam a tela usável por cima.
## Cenas pedidas durante outra entram na fila.

signal acao(nome: String)
## Cena terminada (para a principal encadear a próxima e salvar).
signal terminou(c: Dictionary)

var historia: Historia
var _fila: Array = []
var _cena: Dictionary = {}
var _i := 0
var _fundo: ColorRect
var _caixa: PanelContainer
var _retrato: ColorRect
var _iniciais: Label
var _foto: TextureRect
var _nome: Label
var _texto: Label


func _init(historia_: Historia) -> void:
	historia = historia_
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.55)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.gui_input.connect(_toque)
	add_child(_fundo)
	_caixa = PanelContainer.new()
	_caixa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caixa.offset_left = 16
	_caixa.offset_right = -16
	_caixa.offset_top = -330
	_caixa.offset_bottom = -150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.96)
	sb.border_color = Aba.COR_DESTAQUE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(16)
	_caixa.add_theme_stylebox_override("panel", sb)
	_caixa.gui_input.connect(_toque)
	add_child(_caixa)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.add_child(h)
	_retrato = ColorRect.new()
	_retrato.custom_minimum_size = Vector2(120, 140)
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_retrato)
	_iniciais = Label.new()
	_iniciais.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_iniciais.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_iniciais.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_iniciais.add_theme_font_size_override("font_size", 40)
	_retrato.add_child(_iniciais)
	# Retrato final (Assets): por cima do placeholder quando o arquivo existe.
	_foto = TextureRect.new()
	_foto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retrato.add_child(_foto)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 24)
	_nome.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(_nome)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 30)
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		visible = false
		return
	_cena = _fila.pop_front()
	_i = 0
	visible = true
	_fundo.visible = bool(_cena.get("bloqueia", false))
	_fundo.mouse_filter = Control.MOUSE_FILTER_STOP if _fundo.visible else Control.MOUSE_FILTER_IGNORE
	_mostrar()


## Mostra a fala atual; ações seguidas executam antes de parar na próxima fala.
func _mostrar() -> void:
	var falas: Array = _cena["falas"]
	while _i < falas.size() and falas[_i].has("acao"):
		acao.emit(String(falas[_i]["acao"]))
		_i += 1
	if _i >= falas.size():
		_fim()
		return
	var f: Dictionary = falas[_i]
	var p := historia.personagem(String(f["quem"]))
	var sistema: bool = f["quem"] == "sistema"
	_retrato.visible = not sistema
	_retrato.color = Color(String(p.get("cor", "#444444")))
	var nome := String(p.get("nome", f["quem"]))
	_iniciais.text = "".join(Array(nome.split(" ", false)).slice(0, 2).map(func(x): return String(x).substr(0, 1)))
	_foto.texture = null if sistema else Assets.get_asset(String(f["quem"]), "retrato")
	_iniciais.visible = _foto.texture == null
	_nome.text = nome
	_texto.text = String(f["texto"])
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if sistema else HORIZONTAL_ALIGNMENT_LEFT


func _toque(ev: InputEvent) -> void:
	var toque: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
			or (ev is InputEventScreenTouch and ev.pressed)
	if toque and not _cena.is_empty():
		accept_event()
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
	_proxima()
