class_name Dialogo
extends Control
## Diálogo da história (decisão 32), em cena: a tela escurece, o cenário da cena
## aparece ao fundo (data/historia.json → cenarios, com um zoom lento), o
## personagem que fala entra deslizando de lado em corpo inteiro (Assets,
## variante "corpo"), ocupando quase toda a tela, e na sequência a caixa com nome
## e fala aparece no centro, por cima dele, com o texto sendo digitado. Quando
## outro personagem fala, o anterior sai e o novo entra. Sem a arte (ou falas do
## sistema), só a caixa. Tocar completa o texto, depois avança (ou, no meio da
## entrada, completa a animação). Ações de tutorial no meio da cena saem pelo
## sinal `acao` quando a fala chega nelas; quando a cena abre uma tela ou destaca
## algo, o cenário sai e o personagem fica translúcido para o jogo aparecer.
## Cenas pedidas durante outra entram na fila. O primeiro momento de cada
## capítulo abre com um cartão (historia.json → capitulos).
## Ações próprias do diálogo: [ESCURO] (a tela fica preta até [CLARO] ou o fim da
## sequência), [PAUSA] (um silêncio sem caixa), [TREMOR] (a tela treme),
## [CENARIO:id] (troca o fundo) e [ILUSTRACAO:id] (um quadro de tela cheia do
## momento; as falas seguem embaixo, sem o personagem, até o próximo cenário).
## Falas aceitam variáveis do jogo ({pista}, {saldo}...: Historia.variaveis) e,
## na primeira vez que alguém fala, o nome vem com o papel (personagens.json →
## papel).

signal acao(nome: String)
## Cena terminada (para a principal encadear a próxima e salvar).
signal terminou(c: Dictionary)

## Apresentação, não balanceamento.
const ENTRADA_S := 0.35
const CAIXA_ATRASO_S := 0.2
const CAIXA_S := 0.22
const ALTURA_CORPO := 0.86  # fração da altura da tela
const PAUSA_S := 1.6
const LETRAS_POR_S := 55.0
const CENARIO_S := 0.6  # troca de fundo
const ZOOM_CENARIO := 1.07  # zoom lento do fundo
const ZOOM_S := 22.0
const FAIXA := 0.07  # faixas de cinema, fração da altura
const CARTAO_S := 2.4  # cartão de capítulo, inteiro
const TOM := {"noite": Color(0.42, 0.48, 0.7), "vazio": Color(0.58, 0.58, 0.6), "frio": Color(0.74, 0.8, 0.92)}
## Ações que o próprio diálogo executa (não vão para a principal).
const LOCAIS := ["ESCURO", "CLARO", "PAUSA", "TREMOR"]

var historia: Historia
var _fila: Array = []
var _cena: Dictionary = {}
var _i := 0
var _fundo: ColorRect
var _cenario: TextureRect
var _vinheta: TextureRect
var _cenario_id := ""
var _ilustrando := false
var _corpo: TextureRect
var _quem := ""
var _faixas: Array[ColorRect] = []
var _caixa: PanelContainer
var _nome: Label
var _texto: Label
var _cartao: Control
var _cartao_rotulo: Label
var _cartao_titulo: Label
var _tween: Tween
var _tw_texto: Tween
var _tw_cartao: Tween
var _tw_zoom: Tween
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
	_cenario = TextureRect.new()
	_cenario.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cenario.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cenario.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cenario.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cenario.visible = false
	add_child(_cenario)
	# Vinheta: escurece o alto e, mais, o pé da tela (onde ficam a caixa e o
	# corpo), para o texto ler bem sobre qualquer fundo.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.28, 0.6, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.2), Color(0, 0, 0, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_vinheta = TextureRect.new()
	_vinheta.texture = gt
	_vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	_vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vinheta.visible = false
	add_child(_vinheta)
	_corpo = TextureRect.new()
	_corpo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_corpo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_corpo)
	for embaixo in [false, true]:
		var f := ColorRect.new()
		f.color = Color.BLACK
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.anchor_left = 0.0
		f.anchor_right = 1.0
		f.anchor_top = 1.0 if embaixo else 0.0
		f.anchor_bottom = f.anchor_top
		add_child(f)
		_faixas.append(f)
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
	_caixa.offset_left = 24
	_caixa.offset_right = -24
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_posicionar_caixa(false)
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
	_montar_cartao()
	visible = false


## Cartão de capítulo: tela preta, "Capítulo N" pequeno e o título grande.
func _montar_cartao() -> void:
	_cartao = ColorRect.new()
	(_cartao as ColorRect).color = Color.BLACK
	_cartao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cartao.gui_input.connect(_toque_cartao)
	_cartao.visible = false
	add_child(_cartao)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(v)
	_cartao_rotulo = Label.new()
	_cartao_rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao_rotulo.add_theme_font_size_override("font_size", 24)
	_cartao_rotulo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(_cartao_rotulo)
	var linha := ColorRect.new()
	linha.color = Aba.COR_DESTAQUE
	linha.custom_minimum_size = Vector2(90, 3)
	linha.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(linha)
	_cartao_titulo = Label.new()
	_cartao_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartao_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cartao_titulo.add_theme_font_size_override("font_size", 54)
	v.add_child(_cartao_titulo)


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
		_trocar_cenario("")
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
	_trocar_cenario(String(_cena.get("cenario", "")))
	if not _capitulo_novo():
		_mostrar()


## O primeiro momento de um capítulo abre com o cartão; a cena começa quando ele
## some (ou ao tocar).
func _capitulo_novo() -> bool:
	var cap := String(_cena.get("capitulo", ""))
	var titulos: Dictionary = historia.dados.historia().get("capitulos", {})
	var flag := "CAPITULO_" + cap
	if cap == "" or not titulos.has(cap) or historia.jogador.flags.has(flag):
		return false
	historia.jogador.flags[flag] = true
	var n: int = titulos.keys().find(cap)
	_cartao_rotulo.text = "PRÓLOGO" if n == 0 else "CAPÍTULO %d" % n
	_cartao_titulo.text = String(titulos[cap])
	_caixa.visible = false
	_corpo.visible = false
	_cartao.visible = true
	_cartao.modulate.a = 0.0
	if _tw_cartao != null:
		_tw_cartao.kill()
	_tw_cartao = create_tween()
	_tw_cartao.tween_property(_cartao, "modulate:a", 1.0, CARTAO_S * 0.2)
	_tw_cartao.tween_interval(CARTAO_S * 0.6)
	_tw_cartao.tween_property(_cartao, "modulate:a", 0.0, CARTAO_S * 0.2)
	_tw_cartao.tween_callback(_fim_cartao)
	return true


func _fim_cartao() -> void:
	if not _cartao.visible:
		return
	_cartao.visible = false
	_caixa.visible = true
	_mostrar()


func _toque_cartao(ev: InputEvent) -> void:
	var toque: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
			or (ev is InputEventScreenTouch and ev.pressed)
	if toque:
		accept_event()
		if _tw_cartao != null:
			_tw_cartao.kill()
		_fim_cartao()


## Mostra a fala atual; ações seguidas executam antes de parar na próxima fala.
func _mostrar() -> void:
	var falas: Array = _cena["falas"]
	while _i < falas.size() and falas[_i].has("acao"):
		var nome_acao := String(falas[_i]["acao"])
		_i += 1
		if nome_acao.begins_with("CENARIO:"):
			_trocar_cenario(nome_acao.get_slice(":", 1))
			continue
		if nome_acao.begins_with("ILUSTRACAO:"):
			_trocar_cenario(nome_acao.get_slice(":", 1), true)
			continue
		match nome_acao:
			"ESCURO":
				# Tela preta (o acidente): segue no escuro até [CLARO].
				_escuro = true
				_corpo.visible = false
				_quem = ""
				_trocar_cenario("")
				create_tween().tween_property(_fundo, "color:a", 1.0, 0.8)
				continue
			"CLARO":
				_escuro = false
				create_tween().tween_property(_fundo, "color:a", 0.62, 0.8)
				continue
			"TREMOR":
				_tremer()
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
		# A cena mostra o jogo (abre uma tela ou destaca algo): o cenário sai e o
		# personagem fica translúcido para o elemento aparecer.
		if nome_acao.begins_with("HIGHLIGHT_") or nome_acao.begins_with("OPEN_"):
			_trocar_cenario("")
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
	var atraso := 0.0
	if quem != _quem:
		atraso = _entrar(quem, sistema)
	_quem = quem
	_digitar(atraso)


## Personagem novo: o anterior sai, o novo entra deslizando, depois a caixa.
## Devolve quanto tempo falta para a caixa aparecer. Sobre uma ilustração, sem
## corpo: o quadro é o personagem.
func _entrar(quem: String, sistema: bool) -> float:
	if _tween != null:
		_tween.kill()
	var tex: Texture2D = null if sistema or _ilustrando else _textura(quem)
	var tela := get_viewport_rect().size
	_lado = -_lado
	_corpo.texture = tex
	_corpo.visible = tex != null
	var x_final := _corpo.position.x
	_caixa.modulate.a = 0.0
	_animando = true
	_tween = create_tween()
	var atraso := CAIXA_S
	if tex != null:
		_corpo.position.x = x_final + _lado * tela.x
		_corpo.modulate.a = 0.25 if _translucido else 1.0
		_tween.tween_property(_corpo, "position:x", x_final, ENTRADA_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(CAIXA_ATRASO_S)
		atraso += ENTRADA_S + CAIXA_ATRASO_S
	_tween.tween_property(_caixa, "modulate:a", 1.0, CAIXA_S)
	_tween.tween_callback(func(): _animando = false)
	return atraso


## O texto aparece letra a letra; tocar completa.
func _digitar(atraso: float) -> void:
	if _tw_texto != null:
		_tw_texto.kill()
	_texto.visible_ratio = 0.0
	_tw_texto = create_tween()
	if atraso > 0.0:
		_tw_texto.tween_interval(atraso)
	_tw_texto.tween_property(_texto, "visible_ratio", 1.0, maxf(_texto.text.length() / LETRAS_POR_S, 0.05))


func _digitando() -> bool:
	return _tw_texto != null and _tw_texto.is_running() and _texto.visible_ratio < 1.0


## Fundo da cena ("" tira). Sem a arte, a provisória com o tom do catálogo.
func _trocar_cenario(id: String, ilustracao := false) -> void:
	var chave := ("i:" if ilustracao else "c:") + id
	if chave == _cenario_id:
		return
	_cenario_id = chave if id != "" else ""
	_ilustrando = ilustracao and id != ""
	if _ilustrando:
		_corpo.visible = false
		_quem = ""
	_posicionar_caixa(_ilustrando)
	var tex: Texture2D = null
	var tom := Color.WHITE
	if id != "":
		var cat: Dictionary = historia.dados.historia().get("ilustracoes" if ilustracao else "cenarios", {}).get(id, {})
		tex = Assets.get_asset(id, "ilustracao" if ilustracao else "cenario")
		if tex == null and cat.has("provisorio"):
			tex = Assets.get_asset(String(cat["provisorio"]), "ui")
			tom = TOM.get(String(cat.get("tom", "")), Color.WHITE)
	if tex == null:
		if _cenario.visible:
			var tw := create_tween().set_parallel()
			tw.tween_property(_cenario, "modulate:a", 0.0, CENARIO_S)
			tw.tween_property(_vinheta, "modulate:a", 0.0, CENARIO_S)
			tw.chain().tween_callback(func():
				if _cenario_id == "":
					_cenario.visible = false
					_vinheta.visible = false)
		_faixas_cinema(false)
		return
	_cenario.texture = tex
	_cenario.self_modulate = tom
	_cenario.visible = true
	_vinheta.visible = true
	_cenario.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_cenario, "modulate:a", 1.0, CENARIO_S * (2.0 if ilustracao else 1.0))
	tw.tween_property(_vinheta, "modulate:a", 1.0, CENARIO_S)
	# Zoom lento: o quadro respira.
	if _tw_zoom != null:
		_tw_zoom.kill()
	_cenario.pivot_offset = get_viewport_rect().size / 2.0
	_cenario.scale = Vector2.ONE
	_tw_zoom = create_tween()
	_tw_zoom.tween_property(_cenario, "scale", Vector2.ONE * ZOOM_CENARIO, ZOOM_S).set_trans(Tween.TRANS_SINE)
	_faixas_cinema(true)


func _faixas_cinema(ligar: bool) -> void:
	var h := get_viewport_rect().size.y * FAIXA if ligar else 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_faixas[0], "offset_bottom", h, CENARIO_S)
	tw.tween_property(_faixas[1], "offset_top", -h, CENARIO_S)


## Sobre uma ilustração, a caixa desce para o quadro aparecer.
func _posicionar_caixa(embaixo: bool) -> void:
	_caixa.anchor_top = 0.8 if embaixo else 0.58
	_caixa.anchor_bottom = _caixa.anchor_top


func _tremer() -> void:
	var tw := create_tween()
	for k in 10:
		var amp := 18.0 * (1.0 - k / 10.0)
		tw.tween_property(self, "position", Vector2(randf_range(-amp, amp), randf_range(-amp, amp)), 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


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
			if _digitando():
				_tw_texto.custom_step(10.0)
			return
		if _digitando():
			_tw_texto.custom_step(10.0)  # completa o texto
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
			var nome := String(falas[_i]["acao"])
			if not nome in LOCAIS and not nome.contains(":"):
				acao.emit(nome)
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
