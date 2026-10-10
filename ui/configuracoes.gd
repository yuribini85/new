class_name Configuracoes
extends RefCounted
## Tela de Configurações (engrenagem do cabeçalho): som, gráficos, corridas
## aceleradas e a compra Sem anúncios (decisão 39), testes e versão. Monta o
## conteúdo do painel modal com os componentes de uma aba (`aba`).


## `acelerar`: abre a tela da aceleração. `comprar`: compra Sem anúncios.
## `testes(v)`: modo de playtest e cenários (aba Carreira).
static func montar(aba: Aba, v: VBoxContainer, jogador: Node, acelerar: Callable, comprar: Callable,
		testes: Callable) -> void:
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
	vol.custom_minimum_size = Vector2(0, 48)
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol.value_changed.connect(func(x):
		Preferencias.volume = x
		Preferencias.aplicar())
	vol.drag_ended.connect(func(_mudou): Preferencias.salvar())
	h.add_child(vol)

	_secao(aba, v, "GRÁFICOS")
	_chave(aba, v, "Efeitos leves", "Sem sombras, neblina e faíscas no 3D. Para aparelhos mais fracos; vale a partir da próxima corrida.",
			Preferencias.efeitos_leves, func(x): Preferencias.efeitos_leves = x)
	_chave(aba, v, "Limitar a 30 quadros por segundo", "Economiza bateria; o movimento fica menos suave.",
			Preferencias.limitar_fps, func(x): Preferencias.limitar_fps = x)
	_chave(aba, v, "Reduzir animações", "Fundo da tela inicial parado e menos movimento na interface.",
			Preferencias.reduzir_animacoes, func(x): Preferencias.reduzir_animacoes = x)
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
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(func():
			Preferencias.vista_corrida = m[0]
			Preferencias.salvar())
		vistas.add_child(b)
	v.add_child(vistas)

	_secao(aba, v, "CORRIDAS ACELERADAS")
	var ativa := Aceleracao.ativa(jogador)
	aba.rotulo("Ativa: %s" % Aceleracao.texto_tempo(Aceleracao.restante_s(jogador)) if ativa
			else "Desligada. Um vídeo deixa as corridas mais rápidas por um tempo.",
			Aba.FONTE_PEQUENA, Cabecalho.COR_NUMERO if ativa else Aba.COR_SECUNDARIA, v)
	_botao(v, "Acelerar corridas", acelerar)
	cartao_sem_anuncios(aba, v, comprar)

	testes.call(v)  # traz o próprio separador e título (Modo de playtest)

	if jogador.historia != null and String(jogador.personagem) != "":
		_secao(aba, v, "HISTÓRIA")
		aba.botao_texto("Diário de conversas", func():
			aba.painel.emit("Diário", func(pv): Diario.montar(aba, pv, jogador), []), v)

	_secao(aba, v, "CARREIRA")
	# Recomeçar pede confirmação numa janela própria (apaga todo o progresso).
	aba.botao_texto("Recomeçar carreira", func():
		aba.painel.emit("Recomeçar carreira?", func(pv):
			aba.rotulo("Apagar todo o progresso e voltar ao saldo inicial?", Aba.FONTE_PEQUENA + 2, Color.WHITE, pv),
			[["Sim, recomeçar", aba._recomecar], ["Cancelar", func(): pass]]), v)

	_secao(aba, v, "SOBRE")
	aba.rotulo("Chrome & Wreckage v%s · build %s" % [ProjectSettings.get_setting("application/config/version", ""),
			Aba.versao()], Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, v)


## Compra única Sem anúncios: a aceleração sem assistir ao vídeo. A compra real
## (loja do aparelho) entra com o plugin, depois do MVP.
static func cartao_sem_anuncios(aba: Aba, v: VBoxContainer, comprar: Callable) -> void:
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


static func _secao(aba: Aba, v: VBoxContainer, t: String) -> void:
	if v.get_child_count() > 0:
		aba.separador(v)
	aba.rotulo(t, Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, v)


static func _chave(aba: Aba, v: VBoxContainer, t: String, detalhe: String, ligado: bool, gravar: Callable) -> void:
	var c := CheckButton.new()
	c.text = t
	c.button_pressed = ligado
	c.add_theme_font_size_override("font_size", Aba.FONTE_PEQUENA + 2)
	c.toggled.connect(func(x):
		gravar.call(x)
		Preferencias.salvar())
	v.add_child(c)
	aba.rotulo(detalhe, Aba.FONTE_PEQUENA - 2, Aba.COR_SECUNDARIA, v)


static func _botao(pai: Control, t: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 64)
	b.pressed.connect(func(): acao.call())
	pai.add_child(b)
	return b
