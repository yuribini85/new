class_name Configuracoes
extends RefCounted
## Tela de Configurações (engrenagem do cabeçalho), no visual da referência do
## usuário: seções com etiqueta amarela; cada opção num cartão com ícone,
## título, descrição e a chave à direita; a vista da corrida em dois cartões;
## o nome salva ao confirmar (sem botão); recomeçar a carreira, discreto, no
## pé; a versão por último. Corridas aceleradas e Sem anúncios ficam no
## marcador ACELERAR (e, depois, na loja de dinheiro real). As ferramentas de
## teste aparecem tocando TOQUES_TESTE vezes na versão (ou já abertas com o
## modo de playtest ligado).
const TOQUES_TESTE := 5
const COR_CARTAO := Color(0.07, 0.075, 0.085, 0.86)
const COR_BORDA := Color(1, 1, 1, 0.1)
static var _testes_abertos := false


## `testes(v)`: modo de playtest e cenários (aba Carreira). `reabrir`: abre as
## Configurações de novo (a volta do Diário e do Recomeçar, que ocupam o painel).
## `loja`: abre a loja de dinheiro real (sem ela, a seção não aparece).
static func montar(aba: Aba, v: VBoxContainer, jogador: Node, testes: Callable, reabrir := Callable(),
		loja := Callable()) -> void:
	var voltar := func():
		if reabrir.is_valid():
			reabrir.call()
	v.add_theme_constant_override("separation", 8)
	if loja.is_valid():
		# Loja de dinheiro real (decisão 101): Pack Elite e Sem anúncios.
		_secao(v, "LOJA")
		_linha_botao(v, "coroa", "PACK ELITE E SEM ANÚNCIOS", loja)
	_secao(v, "SOM")
	var c := _cartao(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	c.add_child(h)
	h.add_child(_icone("volume"))
	h.add_child(_titulo("VOLUME"))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Preferencias.volume
	vol.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)  # a área de toque; o trilho não muda
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_estilo_trilho(vol)
	vol.value_changed.connect(func(x):
		Preferencias.volume = x
		Preferencias.aplicar())
	vol.drag_ended.connect(func(_mudou): Preferencias.salvar())
	h.add_child(vol)

	_secao(v, "GRÁFICOS")
	_chave(v, "efeitos", "Efeitos leves", "Reduz efeitos visuais para melhor desempenho.", Preferencias.efeitos_leves,
			func(x): Preferencias.efeitos_leves = x)
	_chave(v, "fps", "Limitar a 30 quadros por segundo", "Reduz o consumo de bateria.", Preferencias.limitar_fps,
			func(x): Preferencias.limitar_fps = x)
	_chave(v, "animacoes", "Reduzir animações", "Desativa animações secundárias.", Preferencias.reduzir_animacoes,
			func(x): Preferencias.reduzir_animacoes = x)

	_secao(v, "AVISOS")
	_chave(v, "cronometro", "Avisos do aparelho", "Contrato encerrado, tanque cheio, licença pronta.",
			Preferencias.notificacoes, func(x):
				Preferencias.notificacoes = x
				if not x:
					Notificacoes.cancelar())

	_secao(v, "VISTA DA CORRIDA")
	var vistas := HBoxContainer.new()
	vistas.add_theme_constant_override("separation", 10)
	v.add_child(vistas)
	var grupo := ButtonGroup.new()
	for m in [["", "3D", "3d"], ["dados", "DADOS (MAIS LEVE)", "dados"]]:
		vistas.add_child(_cartao_vista(m[0], m[1], m[2], grupo))

	if jogador.historia != null and String(jogador.personagem) != "":
		_secao(v, "SEU NOME")
		# O nome que a Mara usa, trocado aqui; salva ao confirmar ou ao sair do campo.
		var cn := _cartao(v)
		var hn := HBoxContainer.new()
		hn.add_theme_constant_override("separation", 14)
		cn.add_child(hn)
		hn.add_child(_icone("nome"))
		var campo := LineEdit.new()
		campo.text = String(jogador.nome_admin)
		campo.max_length = NomeAdmin.NOME_MAX
		campo.virtual_keyboard_enabled = true
		campo.custom_minimum_size.y = 64
		campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		campo.add_theme_font_size_override("font_size", 28)
		campo.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		campo.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		hn.add_child(campo)
		var salvar := func():
			var novo := campo.text.strip_edges()
			if novo == "" or novo == String(jogador.nome_admin):
				campo.text = String(jogador.nome_admin)
				return
			jogador.nome_admin = novo
			aba.get_node("/root/SaveManager").salvar()
			aba.avisar("Nome trocado: %s." % novo)
		campo.text_submitted.connect(func(_t):
			campo.release_focus()
			salvar.call())
		campo.focus_exited.connect(salvar)

		_secao(v, "HISTÓRIA")
		_linha_botao(v, "diario", "DIÁRIO DE CONVERSAS", func():
			aba.painel.emit("Diário", func(pv): Diario.montar(aba, pv, jogador),
					[["Voltar", voltar]] if reabrir.is_valid() else []))

	# Recomeçar, discreto (apaga todo o progresso; pede confirmação).
	var recomecar := Button.new()
	Tipografia.acao_secundaria(recomecar, "Recomeçar carreira", Aba.COR_RUIM.lightened(0.15), 22, 64)
	recomecar.icon = Aba.arte("cfg_recomecar")
	recomecar.expand_icon = true
	recomecar.add_theme_constant_override("icon_max_width", 30)
	recomecar.add_theme_color_override("icon_normal_color", Aba.COR_RUIM.lightened(0.15))
	recomecar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	recomecar.pressed.connect(func():
		aba.painel.emit("Recomeçar carreira?", func(pv):
			aba.rotulo("Apagar todo o progresso e voltar ao saldo inicial?", Aba.FONTE_PEQUENA + 2, Color.WHITE, pv),
			[["Sim, recomeçar", aba._recomecar], ["Cancelar", voltar]]))
	v.add_child(recomecar)
	var versao := aba.rotulo("Chrome & Wreckage v%s · build %s" % [ProjectSettings.get_setting("application/config/version", ""),
			Aba.versao()], Aba.FONTE_PEQUENA - 4, Color(Aba.COR_SECUNDARIA, 0.7), v)
	versao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var testes_v := VBoxContainer.new()
	v.add_child(testes_v)
	if _testes_abertos or Preferencias.modo_teste != "":
		testes.call(testes_v)  # traz o próprio separador e título (Modo de playtest)
		return
	var toques := {"n": 0}
	versao.mouse_filter = Control.MOUSE_FILTER_STOP
	versao.gui_input.connect(func(ev: InputEvent):
		var toque: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
				or (ev is InputEventScreenTouch and ev.pressed)
		if not toque or _testes_abertos:
			return
		toques["n"] += 1
		if toques["n"] >= TOQUES_TESTE:
			_testes_abertos = true
			testes.call(testes_v))


## Compra única Sem anúncios: a aceleração sem assistir ao vídeo. A compra real
## (loja do aparelho) entra com o plugin, depois do MVP. Sem loja do aparelho
## (a versão Web), o cartão não aparece: os botões só davam erro.
static func cartao_sem_anuncios(aba: Aba, v: VBoxContainer, comprar: Callable) -> void:
	if not tem_loja():
		return
	var c := aba.cartao(Cabecalho.COR_NUMERO, v)
	aba.rotulo("SEM ANÚNCIOS", Aba.FONTE_PEQUENA + 2, Cabecalho.COR_NUMERO, c)
	aba.rotulo("Compra única. Acelera as corridas sem precisar assistir aos vídeos.", Aba.FONTE_PEQUENA,
			Color.WHITE, c)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	c.add_child(h)
	var b := _botao(h, "Comprar", comprar)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r := _botao(h, "Restaurar compra", comprar)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## A plataforma tem loja do aparelho para a compra Sem anúncios (não na Web).
static func tem_loja() -> bool:
	return not OS.has_feature("web")


## Etiqueta amarela inclinada com o nome da seção e dois riscos no fim.
static func _secao(v: VBoxContainer, t: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Tipografia.fonte("display_eb"))
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(0.1, 0.09, 0.07))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Aba.COR_DESTAQUE
	sb.skew = Vector2(0.35, 0.0)
	sb.content_margin_left = 22
	sb.content_margin_right = 30
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	h.add_child(l)
	for k in 2:
		var risco := Label.new()
		var sr := StyleBoxFlat.new()
		sr.bg_color = Color(Aba.COR_DESTAQUE, 0.75 - k * 0.3)
		sr.skew = Vector2(0.35, 0.0)
		sr.content_margin_left = 5
		sr.content_margin_right = 5
		risco.add_theme_stylebox_override("normal", sr)
		risco.size_flags_vertical = Control.SIZE_FILL
		h.add_child(risco)


static func _cartao(v: VBoxContainer) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.border_color = COR_BORDA
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 20
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	v.add_child(p)
	return p


## Ícone da arte do usuário (arte/ui/cfg_<nome>.png), em escala uniforme.
static func _icone(nome: String, tam := 46.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Aba.arte("cfg_" + nome)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(tam, tam)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A arte cfg_<nome>; sem ela, o ícone vetorial do mesmo nome.
static func _icone_ou_vetor(nome: String) -> Control:
	if Aba.arte("cfg_" + nome) != null:
		return _icone(nome)
	var iv := IconeVetor.new(nome, Aba.COR_DESTAQUE)
	iv.custom_minimum_size = Vector2(46, 46)
	iv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return iv


static func _titulo(t: String) -> Label:
	var l := Label.new()
	l.text = t.to_upper()
	Tipografia.rotulo(l, "semibold", 26)
	l.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## Trilho do volume no ocre da interface.
static func _estilo_trilho(s: HSlider) -> void:
	var trilho := StyleBoxFlat.new()
	trilho.bg_color = Color(1, 1, 1, 0.12)
	trilho.set_corner_radius_all(4)
	trilho.content_margin_top = 4
	trilho.content_margin_bottom = 4
	var cheio := trilho.duplicate()
	cheio.bg_color = Aba.COR_DESTAQUE
	s.add_theme_stylebox_override("slider", trilho)
	s.add_theme_stylebox_override("grabber_area", cheio)
	s.add_theme_stylebox_override("grabber_area_highlight", cheio)


## Opção liga/desliga: ícone, título, descrição e a chave à direita.
static func _chave(v: VBoxContainer, icone: String, t: String, descricao: String, ligado: bool, gravar: Callable) -> void:
	var c := _cartao(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	c.add_child(h)
	h.add_child(_icone_ou_vetor(icone))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(col)
	var tl := _titulo(t)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tl)
	var d := Label.new()
	d.text = descricao
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Tipografia.rotulo(d, "regular", 21)
	d.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
	col.add_child(d)
	var chave := ChaveLiga.new(ligado)
	chave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chave.toggled.connect(func(x):
		gravar.call(x)
		Preferencias.salvar())
	h.add_child(chave)


## Cartão da vista da corrida: ícone grande e nome; o escolhido em dourado.
static func _cartao_vista(id: String, nome: String, icone: String, grupo: ButtonGroup) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = grupo
	b.button_pressed = Preferencias.vista_corrida == id
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 124)
	var normal := StyleBoxFlat.new()
	normal.bg_color = COR_CARTAO
	normal.border_color = COR_BORDA
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var marcado := normal.duplicate()
	marcado.bg_color = Aba.COR_DESTAQUE
	marcado.border_color = Aba.COR_DESTAQUE.lightened(0.3)
	marcado.set_border_width_all(2)
	for e in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(e, normal)
	for e in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(e, marcado)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var ic := _icone(icone, 64.0)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var l := Label.new()
	l.text = nome
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(l, "semibold", 26)
	col.add_child(l)
	var pintar := func():
		var on := b.button_pressed
		var cor := Color(0.1, 0.09, 0.07) if on else Color(0.93, 0.91, 0.87)
		ic.modulate = Color(0.12, 0.1, 0.07) if on else Color.WHITE
		l.add_theme_color_override("font_color", cor)
	pintar.call()
	b.toggled.connect(func(_x): pintar.call())
	b.pressed.connect(func():
		Preferencias.vista_corrida = id
		Preferencias.salvar())
	return b


## Linha que abre outra tela: ícone, texto e a seta à direita.
static func _linha_botao(v: VBoxContainer, icone: String, t: String, acao: Callable) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = Tipografia.ALTURA_SECUNDARIA
	var sb := StyleBoxFlat.new()
	sb.bg_color = COR_CARTAO
	sb.border_color = COR_BORDA
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	for e in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(e, sb)
	b.pressed.connect(func(): acao.call())
	v.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20
	h.offset_right = -16
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(_icone_ou_vetor(icone))
	var l := _titulo(t)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var seta := IconeVetor.new("chevron_dir", Aba.COR_SECUNDARIA)
	seta.custom_minimum_size = Vector2(32, 32)
	seta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(seta)


static func _botao(pai: Control, t: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, Tipografia.ALTURA_SECUNDARIA)
	b.pressed.connect(func(): acao.call())
	pai.add_child(b)
	return b
