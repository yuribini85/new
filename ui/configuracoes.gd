class_name Configuracoes
extends RefCounted
## Tela de Configurações (engrenagem do cabeçalho): som, gráficos, corridas
## aceleradas e a compra Sem anúncios (decisão 39), história, carreira e
## versão. As ferramentas de teste ficam escondidas: aparecem tocando
## TOQUES_TESTE vezes na versão (ou já abertas com o modo de playtest ligado).
## Monta o conteúdo do painel modal com os componentes de uma aba (`aba`).
const TOQUES_TESTE := 5
static var _testes_abertos := false


## `acelerar`: abre a tela da aceleração. `comprar`: compra Sem anúncios.
## `testes(v)`: modo de playtest e cenários (aba Carreira). `reabrir`: abre as
## Configurações de novo (a volta do Diário e do Recomeçar, que ocupam o painel).
static func montar(aba: Aba, v: VBoxContainer, jogador: Node, acelerar: Callable, comprar: Callable,
		testes: Callable, reabrir := Callable()) -> void:
	var voltar := func():
		if reabrir.is_valid():
			reabrir.call()
	_secao(aba, v, "SOM")
	var h := aba.fileira(v)
	var lv := aba.rotulo("Volume", Aba.FONTE_PEQUENA + 2, Color.WHITE, h)
	lv.size_flags_horizontal = Control.SIZE_FILL
	lv.autowrap_mode = TextServer.AUTOWRAP_OFF
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Preferencias.volume
	vol.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)  # a área de toque; o trilho não muda
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.value_changed.connect(func(x):
		Preferencias.volume = x
		Preferencias.aplicar())
	vol.drag_ended.connect(func(_mudou): Preferencias.salvar())
	h.add_child(vol)

	_secao(aba, v, "GRÁFICOS")
	_chave(v, "Efeitos leves", Preferencias.efeitos_leves, func(x): Preferencias.efeitos_leves = x)
	_chave(v, "Limitar a 30 quadros por segundo", Preferencias.limitar_fps, func(x): Preferencias.limitar_fps = x)
	_chave(v, "Reduzir animações", Preferencias.reduzir_animacoes, func(x): Preferencias.reduzir_animacoes = x)
	aba.rotulo("Vista da corrida", Aba.FONTE_PEQUENA + 2, Color.WHITE, v)
	var vistas := HBoxContainer.new()
	vistas.add_theme_constant_override("separation", 8)
	var grupo := ButtonGroup.new()
	for m in [["", "3D"], ["dados", "Dados (mais leve)"]]:
		var b := Button.new()
		b.text = m[1]
		b.toggle_mode = true
		b.button_group = grupo
		b.button_pressed = Preferencias.vista_corrida == m[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, Tipografia.ALTURA_SECUNDARIA)
		b.pressed.connect(func():
			Preferencias.vista_corrida = m[0]
			Preferencias.salvar())
		vistas.add_child(b)
	v.add_child(vistas)

	# Sem `acelerar` (antes do fim do tutorial), a seção não aparece.
	if acelerar.is_valid():
		_secao(aba, v, "CORRIDAS ACELERADAS")
		var ativa := Aceleracao.ativa(jogador)
		aba.rotulo("Ativa: %s" % Aceleracao.texto_tempo(Aceleracao.restante_s(jogador)) if ativa
				else "Desligada. Um vídeo deixa as corridas mais rápidas por um tempo.",
				Aba.FONTE_PEQUENA, Cabecalho.COR_NUMERO if ativa else Aba.COR_SECUNDARIA, v)
		_botao(v, "Acelerar corridas", acelerar)
		cartao_sem_anuncios(aba, v, comprar)

	if jogador.historia != null and String(jogador.personagem) != "":
		_secao(aba, v, "SEU NOME")
		# O nome que a Mara usa (o do começo do jogo), trocado aqui. O texto é
		# lido no toque (o teclado do navegador não avisa a cada letra).
		var linha_nome := HBoxContainer.new()
		linha_nome.add_theme_constant_override("separation", 10)
		v.add_child(linha_nome)
		var campo := LineEdit.new()
		campo.text = String(jogador.nome_admin)
		campo.max_length = NomeAdmin.NOME_MAX
		campo.virtual_keyboard_enabled = true
		campo.custom_minimum_size.y = 64
		campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		campo.add_theme_font_size_override("font_size", 26)
		linha_nome.add_child(campo)
		var salvar := func():
			var novo := campo.text.strip_edges()
			if novo == "" or novo == String(jogador.nome_admin):
				campo.text = String(jogador.nome_admin)
				return
			jogador.nome_admin = novo
			aba.get_node("/root/SaveManager").salvar()
			aba.avisar("Nome trocado: %s." % novo)
		campo.text_submitted.connect(func(_t): salvar.call())
		var b_salvar := _botao(linha_nome, "Salvar", salvar)
		b_salvar.custom_minimum_size.x = 150
		_secao(aba, v, "HISTÓRIA")
		var diario := aba.botao_texto("Diário de conversas", func():
			aba.painel.emit("Diário", func(pv): Diario.montar(aba, pv, jogador),
					[["Voltar", voltar]] if reabrir.is_valid() else []), v)
		diario.custom_minimum_size.y = Tipografia.ALTURA_SECUNDARIA

	_secao(aba, v, "CARREIRA")
	# Recomeçar pede confirmação numa janela própria (apaga todo o progresso).
	var recomecar := aba.botao_texto("Recomeçar carreira", func():
		aba.painel.emit("Recomeçar carreira?", func(pv):
			aba.rotulo("Apagar todo o progresso e voltar ao saldo inicial?", Aba.FONTE_PEQUENA + 2, Color.WHITE, pv),
			[["Sim, recomeçar", aba._recomecar], ["Cancelar", voltar]]), v)
	recomecar.custom_minimum_size.y = Tipografia.ALTURA_SECUNDARIA

	_secao(aba, v, "SOBRE")
	var versao := aba.rotulo("Chrome & Wreckage v%s · build %s" % [ProjectSettings.get_setting("application/config/version", ""),
			Aba.versao()], Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, v)
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


static func _secao(aba: Aba, v: VBoxContainer, t: String) -> void:
	if v.get_child_count() > 0:
		aba.separador(v)
	aba.rotulo(t, Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, v)


static func _chave(v: VBoxContainer, t: String, ligado: bool, gravar: Callable) -> void:
	var c := CheckButton.new()
	c.text = t
	c.button_pressed = ligado
	c.add_theme_font_size_override("font_size", Aba.FONTE_PEQUENA + 2)
	c.custom_minimum_size.y = Tipografia.ALTURA_SECUNDARIA
	c.toggled.connect(func(x):
		gravar.call(x)
		Preferencias.salvar())
	v.add_child(c)


static func _botao(pai: Control, t: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, Tipografia.ALTURA_SECUNDARIA)
	b.pressed.connect(func(): acao.call())
	pai.add_child(b)
	return b
