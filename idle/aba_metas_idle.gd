class_name MetasIdle
extends ScrollContainer
## Tela MISSÕES do Chrome Racing Team (docs/idle/plano.md): as missões do dia, como
## a Meta do dia do Chrome & Wreckage. Um cartão por meta com o ícone, o que
## fazer, a barra do progresso e o botão COLETAR (minutos da renda) quando
## cumprida; no alto, quando chegam as próximas.

signal mudou

var tela: Node  # tela_idle.gd: estado
var _lista: VBoxContainer
var _relogio: Label
var _assinatura := ""  # o que está na tela (redesenha só quando muda)


func _init(tela_: Node) -> void:
	tela = tela_
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 12)
	add_child(_lista)
	IdleUI.rolagem_fina(self)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var agora := Time.get_unix_time_from_system()
	if _relogio != null:
		_relogio.text = "Novas missões em " + IdleUI.relogio(_meia_noite(agora) - agora)
	if _assinatura_de(agora) != _assinatura:
		atualizar()


func _assinatura_de(agora: float) -> String:
	var e: IdleEstado = tela.estado
	var est := e.metas_do_dia(agora)
	var partes := [String(est["dia"]), str(est["coletadas"])]
	for id in est["tarefas"]:
		partes.append(str(e.progresso_meta(String(id), agora)))
	partes.append(IdleUI.curto(e.recompensa_meta()))
	return "|".join(partes)


## Segundos Unix da próxima meia-noite do aparelho.
static func _meia_noite(agora: float) -> float:
	var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	var local := agora + bias
	return floorf(local / 86400.0 + 1.0) * 86400.0 - bias


func atualizar() -> void:
	var e: IdleEstado = tela.estado
	var agora := Time.get_unix_time_from_system()
	_assinatura = _assinatura_de(agora)
	for c in _lista.get_children():
		c.queue_free()
	var topo := HBoxContainer.new()
	_lista.add_child(topo)
	var t := IdleUI.rotulo("MISSÕES DIÁRIAS", 30, IdleUI.COR_TEXTO, topo, "display")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relogio = IdleUI.rotulo("", 18, IdleUI.COR_SECUNDARIA, topo)
	_relogio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_relogio.text = "Novas missões em " + IdleUI.relogio(_meia_noite(agora) - agora)
	var est := e.metas_do_dia(agora)
	for id in est["tarefas"]:
		_cartao(e, String(id), agora, String(id) in est["coletadas"])
	var nota := IdleUI.rotulo("Cada missão vale %d minutos da renda da equipe." % int(e.cfg_metas().get("recompensa_min", 0)),
			17, IdleUI.COR_SECUNDARIA, _lista, "regular")
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _cartao(e: IdleEstado, id: String, agora: float, coletada: bool) -> void:
	var t := e.tarefa_meta(id)
	var p := e.progresso_meta(id, agora)
	var pronta := e.meta_pronta(id, agora)
	var cartao := PanelContainer.new()
	var borda := IdleUI.COR_OURO if pronta else IdleUI.COR_BORDA
	cartao.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARTAO, 14, 14, borda, 2 if pronta else 1))
	_lista.add_child(cartao)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	cartao.add_child(h)
	IdleUI.icone(String(t.get("icone", "icone_objetivo")), 48, h, IdleUI.COR_OURO if not coletada else IdleUI.COR_BLOQUEADO)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var texto := String(t.get("texto", ""))
	if texto.contains("%d"):
		texto = texto % int(p[1])
	IdleUI.rotulo(texto.to_upper(), 22, IdleUI.COR_TEXTO if not coletada else IdleUI.COR_BLOQUEADO, v)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	v.add_child(linha)
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.max_value = float(p[1])
	barra.value = float(p[0])
	barra.custom_minimum_size = Vector2(0, 14)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barra.add_theme_stylebox_override("background", IdleUI.caixa(IdleUI.COR_FUNDO, 7, 0, IdleUI.COR_BORDA, 1))
	barra.add_theme_stylebox_override("fill", IdleUI.caixa(IdleUI.COR_OURO if not coletada else IdleUI.COR_BLOQUEADO, 7, 0))
	linha.add_child(barra)
	IdleUI.rotulo("%d/%d" % [p[0], p[1]], 18, IdleUI.COR_SECUNDARIA, linha)
	if coletada:
		var ok := IdleUI.icone("icone_ok", 44, h, IdleUI.COR_GANHO)
		ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return
	var b := IdleUI.botao("COLETAR\n$" + IdleUI.curto(e.recompensa_meta()), IdleUI.COR_OURO, 20, 72, h)
	b.custom_minimum_size.x = 150
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not pronta
	b.pressed.connect(func():
		var v_ := e.coletar_meta(id)
		if v_ <= 0.0:
			return
		Sons.cascata(self, 4)
		tela.celebrar(1)
		tela.ganho_flutuante(v_)
		mudou.emit()
		atualizar())
