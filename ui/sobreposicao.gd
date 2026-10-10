class_name Sobreposicao
extends Control
## Camada por cima das telas: avisos rápidos (confirmação de compra, motivo de
## uma falha) e painéis roláveis (relatório offline, licença conquistada).
## Substitui as janelas do Godot, que não rolavam nem quebravam linha.

const DURACAO_AVISO := 2.6

var _avisos: VBoxContainer
var _painel_raiz: Control
var _painel_conteudo: VBoxContainer
var _painel_titulo: Label
var _painel_botoes: HFlowContainer
var _margem: MarginContainer
var _titulo_cor := Color.WHITE
var _estilo := {}
var _fechar_x: Button
var _vao_x: Control
## Largura útil do título no cartão (px de uma tela de 720).
const LARGURA_TITULO := 720.0 - 2.0 * 24.0 - 2.0 * 22.0 - 60.0
## Cortina preta do fim da corrida: escurece a tela antes do resultado e sai
## quando o painel fecha.
var _cortina: ColorRect
var _tw_cortina: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina = ColorRect.new()
	_cortina.color = Color.BLACK
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.modulate.a = 0.0
	_cortina.visible = false
	add_child(_cortina)
	# Painel modal: fundo escurecido que segura o toque, cartão com rolagem.
	_painel_raiz = Control.new()
	_painel_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_painel_raiz.visible = false
	add_child(_painel_raiz)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.7)
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_painel_raiz.add_child(escuro)
	escuro.gui_input.connect(func(ev):
		if _estilo.get("fora_fecha", false) and ev is InputEventMouseButton and ev.pressed:
			fechar())
	var margem := MarginContainer.new()
	_margem = margem
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	for lado in ["top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 90)
	_painel_raiz.add_child(margem)
	var cartao := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	sb.border_color = Aba.COR_DESTAQUE
	sb.set_border_width_all(2)
	cartao.add_theme_stylebox_override("panel", sb)
	margem.add_child(cartao)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	cartao.add_child(v)
	_painel_titulo = Label.new()
	Tipografia.rotulo(_painel_titulo, "semibold", 40)
	_painel_titulo.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	_painel_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_painel_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Linha do título: o × à direita (só com fora_fecha) e um vão do mesmo
	# tamanho à esquerda, para o título centrado ficar no meio do cartão.
	var linha_titulo := HBoxContainer.new()
	linha_titulo.add_theme_constant_override("separation", 0)
	v.add_child(linha_titulo)
	_vao_x = Control.new()
	_vao_x.custom_minimum_size = Vector2(56, 0)
	linha_titulo.add_child(_vao_x)
	linha_titulo.add_child(_painel_titulo)
	_fechar_x = Button.new()
	_fechar_x.text = "×"
	_fechar_x.flat = true
	_fechar_x.focus_mode = Control.FOCUS_NONE
	_fechar_x.add_theme_font_size_override("font_size", 48)
	_fechar_x.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	_fechar_x.custom_minimum_size = Vector2(56, 56)
	_fechar_x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_fechar_x.visible = false
	_fechar_x.pressed.connect(fechar)
	linha_titulo.add_child(_fechar_x)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(rolagem)
	_painel_conteudo = VBoxContainer.new()
	_painel_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_painel_conteudo.add_theme_constant_override("separation", 12)
	rolagem.add_child(_painel_conteudo)
	# Quebra linha quando os botões não cabem lado a lado (celular).
	_painel_botoes = HFlowContainer.new()
	_painel_botoes.add_theme_constant_override("h_separation", 12)
	_painel_botoes.add_theme_constant_override("v_separation", 12)
	v.add_child(_painel_botoes)
	# Avisos no topo, empilhados; somem sozinhos.
	_avisos = VBoxContainer.new()
	_avisos.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_avisos.offset_left = 20
	_avisos.offset_right = -20
	_avisos.offset_top = 70
	_avisos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avisos.add_theme_constant_override("separation", 8)
	add_child(_avisos)


## Aviso curto no topo. ok = false: em vermelho (falha, com o motivo).
func avisar(texto: String, ok := true) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.32, 0.18, 0.96) if ok else Color(0.42, 0.12, 0.1, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = ("✓ " if ok else "✗ ") + texto
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 26)
	p.add_child(l)
	_avisos.add_child(p)
	while _avisos.get_child_count() > 3:
		var velho := _avisos.get_child(0)
		_avisos.remove_child(velho)
		velho.queue_free()
	if is_inside_tree():
		# Ligado ao próprio aviso: se ele já saiu (mais de 3), a ligação some junto.
		get_tree().create_timer(DURACAO_AVISO).timeout.connect(p.queue_free)


## Painel modal com rolagem. montar(vbox) preenche o conteúdo; botoes =
## [[texto, Callable]] (vazio: só "OK"). Qualquer botão fecha o painel.
## estilo (opcional): {"titulo_centro": bool, "titulo_max": px (o título
## diminui até caber), "principal": a ação única em destaque, "fora_fecha":
## tocar fora do cartão ou no × fecha, "habilitado": false apaga a ação}.
func abrir(titulo: String, montar: Callable, botoes: Array = [], estilo: Dictionary = {}) -> void:
	for c in _painel_conteudo.get_children():
		c.queue_free()
	for c in _painel_botoes.get_children():
		c.queue_free()
	_estilo = estilo
	_painel_titulo.text = titulo
	_painel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if estilo.get("titulo_centro", false) \
			else HORIZONTAL_ALIGNMENT_LEFT
	var tam: int = int(estilo.get("titulo_max", 40))
	var f := _painel_titulo.get_theme_font("font")
	while tam > 40 and f.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > LARGURA_TITULO:
		tam -= 4
	_painel_titulo.add_theme_font_size_override("font_size", tam)
	_fechar_x.visible = estilo.get("fora_fecha", false)
	_vao_x.visible = _fechar_x.visible and estilo.get("titulo_centro", false)
	montar.call(_painel_conteudo)
	if botoes.is_empty():
		botoes = [["OK", func(): pass]]
	for i in botoes.size():
		var b: Array = botoes[i]
		var bt := Button.new()
		bt.text = b[0]
		bt.custom_minimum_size = Vector2(150, 76)
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.disabled = not estilo.get("habilitado", true)
		if i == 0 and (botoes.size() > 1 or estilo.get("principal", false)):
			# A ação principal em destaque.
			var sb := StyleBoxFlat.new()
			sb.bg_color = Aba.COR_DESTAQUE
			sb.set_corner_radius_all(10)
			sb.set_content_margin_all(12)
			for estado in ["normal", "hover", "pressed", "focus"]:
				bt.add_theme_stylebox_override(estado, sb)
			var apagado := sb.duplicate()
			apagado.bg_color = Aba.COR_DESTAQUE.darkened(0.55)
			bt.add_theme_stylebox_override("disabled", apagado)
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				bt.add_theme_color_override(c, Color(0.1, 0.1, 0.1))
			if estilo.get("principal", false):
				Tipografia.rotulo(bt, "semibold", 36)
				bt.custom_minimum_size.y = 92
		# Terceiro item opcional: ícone da arte da interface.
		if b.size() > 2 and b[2] == "giros":
			Aba.moeda(bt)  # preço: a moeda antes do valor
		elif b.size() > 2 and b[2] is String:
			Aba.com_icone(bt, b[2])
		bt.pressed.connect(func():
			fechar()
			b[1].call())
		_painel_botoes.add_child(bt)
	_painel_raiz.visible = true
	_ajustar.call_deferred()


## Cartão do tamanho do conteúdo, centrado (sem vazio quando há pouco a mostrar).
func _ajustar() -> void:
	# Espera o texto quebrar linha e as imagens assentarem antes de medir.
	await get_tree().process_frame
	await get_tree().process_frame
	var altura_tela := size.y if size.y > 0.0 else 1280.0
	var conteudo := _painel_conteudo.get_combined_minimum_size().y
	var total := conteudo + _painel_titulo.get_combined_minimum_size().y + _painel_botoes.get_combined_minimum_size().y \
			+ 44.0 + 28.0 + 6.0
	var margem := maxf(60.0, (altura_tela - total) * 0.5)
	_margem.add_theme_constant_override("margin_top", int(margem))
	_margem.add_theme_constant_override("margin_bottom", int(margem))


func fechar() -> void:
	_painel_raiz.visible = false
	if _cortina.visible:
		escurecer(false, 0.4)


## Cortina: escurece (true) ou clareia a tela em `duracao` s.
func escurecer(sim: bool, duracao: float) -> void:
	if _tw_cortina != null:
		_tw_cortina.kill()
	_cortina.visible = true
	_tw_cortina = create_tween().set_trans(Tween.TRANS_SINE)
	_tw_cortina.tween_property(_cortina, "modulate:a", 1.0 if sim else 0.0, duracao)
	if not sim:
		_tw_cortina.tween_callback(func(): _cortina.visible = false)


func aberto() -> bool:
	return _painel_raiz.visible
