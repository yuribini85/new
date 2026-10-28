class_name MetasIdle
extends ScrollContainer
## Tela MISSÕES do The Fastfather (docs/idle/plano.md): no alto a Gazeta de
## hoje (a manchete e o bônus do dia), o presente do chefão (7 dias seguidos) e
## o desafio de fim de semana da família rival; depois as missões do dia, como
## a Meta do dia do Chrome & Wreckage. Um cartão por meta com o ícone, o que
## fazer, a barra do progresso e o botão COLETAR (minutos da renda) quando
## cumprida; no alto, quando chegam as próximas.

## Um ícone por dia do presente: o dinheiro cresce; o 7º é o capanga.
const ICONES_PRESENTE := ["notas", "moedas", "saco_dinheiro", "saco_dinheiro_2", "barras_ouro", "barras_ouro", "chapeu_fedora"]
const EFEITOS := {"premio": "PRÊMIOS", "renda": "LUCRO", "oficina": "OFICINA", "gorjeta": "GORJETA DO JORNALEIRO",
		"potencia": "MOTOR"}

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
	var agora: float = tela.estado.relogio()
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
	partes.append(str(e.presente) + str(e.presente_pronto(agora)) + IdleUI.curto(e.valor_presente(e.dia_do_presente(agora))))
	partes.append(str(e.estado_desafio(agora)) + str(e.fim_de_semana(agora)) + str(e.tacas))
	return "|".join(partes)


## Segundos Unix da próxima meia-noite do aparelho.
static func _meia_noite(agora: float) -> float:
	var bias := float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0
	var local := agora + bias
	return floorf(local / 86400.0 + 1.0) * 86400.0 - bias


func atualizar() -> void:
	var e: IdleEstado = tela.estado
	var agora: float = tela.estado.relogio()
	_assinatura = _assinatura_de(agora)
	for c in _lista.get_children():
		c.queue_free()
	var topo := HBoxContainer.new()
	_lista.add_child(topo)
	var t := IdleUI.rotulo("MISSÕES DIÁRIAS", 30, IdleUI.COR_TEXTO, topo, "deco")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_relogio = IdleUI.rotulo("", 18, IdleUI.COR_SECUNDARIA, topo)
	_relogio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_relogio.text = "Novas missões em " + IdleUI.relogio(_meia_noite(agora) - agora)
	_gazeta(e)
	_presente(e, agora)
	_desafio(e, agora)
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
	b.custom_minimum_size.x = 200
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


## Texto do bônus: "PRÊMIOS +25%", "OFICINA −25%".
static func texto_bonus(efeito: String, bonus: float) -> String:
	var sinal := "−" if efeito == "oficina" else "+"
	return "%s %s%d%%" % [String(EFEITOS.get(efeito, efeito.to_upper())), sinal, roundi(bonus * 100.0)]


## O recorte da Gazeta do Cais de hoje: a manchete e o que ela muda no dia.
func _gazeta(e: IdleEstado) -> void:
	var m := e.manchete_do_dia()
	if m.is_empty():
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", IdleUI.caixa(JornalIdle.PAPEL, 2, 14, Color("8a7a5a"), 1))
	_lista.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var nome := IdleUI.rotulo(JornalIdle.NOME + " · HOJE", 18, JornalIdle.TINTA, v, "deco")
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var filete := ColorRect.new()
	filete.color = JornalIdle.TINTA
	filete.custom_minimum_size = Vector2(0, 2)
	v.add_child(filete)
	var t := IdleUI.rotulo(String(m["manchete"]), 28, JornalIdle.TINTA, v, "display")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 600
	var b := IdleUI.rotulo(texto_bonus(String(m["efeito"]), float(m["bonus"])) + " ATÉ A MEIA-NOITE", 20,
			IdleUI.COR_VINHO, v)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## O presente do chefão: os 7 dias em fila, o de hoje em ouro com COLETAR.
func _presente(e: IdleEstado, agora: float) -> void:
	if e.cfg_presente().is_empty():
		return
	var cartao := PanelContainer.new()
	var pronto := e.presente_pronto(agora)
	cartao.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARTAO, 14, 14,
			IdleUI.COR_OURO if pronto else IdleUI.COR_BORDA, 2 if pronto else 1))
	_lista.add_child(cartao)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	cartao.add_child(v)
	IdleUI.rotulo("PRESENTE DO CHEFÃO", 24, IdleUI.COR_TEXTO, v, "deco")
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	v.add_child(fila)
	var hoje := e.dia_do_presente(agora)
	for n in range(1, 8):
		var feito := n < hoje or (n == hoje and not pronto)
		var este := n == hoje and pronto
		var caixa := PanelContainer.new()
		caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cor := IdleUI.COR_OURO if este else (IdleUI.COR_FUNDO if not feito else IdleUI.COR_CARTAO)
		caixa.add_theme_stylebox_override("panel", IdleUI.caixa(cor, 8, 6, IdleUI.COR_OURO_ESCURO if este else IdleUI.COR_BORDA, 1))
		fila.add_child(caixa)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 2)
		caixa.add_child(cv)
		var tinta := IdleUI.COR_TINTA if este else (IdleUI.COR_BLOQUEADO if feito else IdleUI.COR_TEXTO)
		var d := IdleUI.rotulo("DIA %d" % n, 15, tinta, cv)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ic := TextureRect.new()
		ic.texture = IdleUI.icone_hud(ICONES_PRESENTE[n - 1])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
		ic.custom_minimum_size = Vector2(0, 40)
		ic.modulate = Color(1, 1, 1, 0.35) if feito else Color.WHITE
		cv.add_child(ic)
	if not pronto:
		var l := IdleUI.rotulo("Volte amanhã: dia seguido avança, dia perdido volta ao 1º.", 17, IdleUI.COR_SECUNDARIA, v, "regular")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 600
		return
	var texto := "COLETAR CAPANGA" if hoje >= 7 else "COLETAR $" + IdleUI.curto(e.valor_presente(hoje))
	var b := IdleUI.botao(texto, IdleUI.COR_OURO, 22, 64, v)
	b.pressed.connect(func():
		var r := e.coletar_presente(tela.dados)
		if r.is_empty():
			return
		Sons.cascata(self, 5)
		tela.celebrar(2)
		if r.has("dinheiro"):
			tela.ganho_flutuante(float(r["dinheiro"]))
		mudou.emit()
		atualizar())


## O desafio de fim de semana: a família da vez, as vitórias e a taça.
func _desafio(e: IdleEstado, agora: float) -> void:
	if e.cfg_fim_de_semana().is_empty():
		return
	var familias: Array = CenaQuadrinho.carregar("familias").get("nomes", [])
	var fds := e.fim_de_semana(agora)
	# Fora do fim de semana o cartão anuncia a família do próximo sábado.
	var quando := agora
	while not e.fim_de_semana(quando):
		quando += 86400.0
	var fam := e.familia_do_desafio(familias, quando)
	var d := e.estado_desafio(agora)
	var meta := int(e.cfg_fim_de_semana().get("vitorias", 1))
	var pronto := e.desafio_pronto()
	var cartao := PanelContainer.new()
	cartao.add_theme_stylebox_override("panel", IdleUI.caixa(IdleUI.COR_CARTAO, 14, 14,
			IdleUI.COR_VINHO_CLARO if fds else IdleUI.COR_BORDA, 2 if fds else 1))
	_lista.add_child(cartao)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	cartao.add_child(v)
	IdleUI.rotulo("DESAFIO DA FAMÍLIA %s" % fam.to_upper(), 24, IdleUI.COR_VINHO_CLARO, v, "deco")
	if not fds:
		var l := IdleUI.rotulo("Sábado e domingo: prêmios %s e a taça para quem vencer %d corridas." % [
				texto_bonus("premio", float(e.cfg_fim_de_semana().get("premio", 0.0))).trim_prefix("PRÊMIOS "), meta],
				19, IdleUI.COR_TEXTO, v, "regular")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 600
	else:
		IdleUI.rotulo(texto_bonus("premio", float(e.cfg_fim_de_semana().get("premio", 0.0))) + " NO FIM DE SEMANA", 19,
				IdleUI.COR_GANHO, v)
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 10)
		v.add_child(linha)
		var barra := ProgressBar.new()
		barra.show_percentage = false
		barra.max_value = meta
		barra.value = mini(int(d["vitorias"]), meta)
		barra.custom_minimum_size = Vector2(0, 14)
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		barra.add_theme_stylebox_override("background", IdleUI.caixa(IdleUI.COR_FUNDO, 7, 0, IdleUI.COR_BORDA, 1))
		barra.add_theme_stylebox_override("fill", IdleUI.caixa(IdleUI.COR_VINHO_CLARO, 7, 0))
		linha.add_child(barra)
		IdleUI.rotulo("%d/%d VITÓRIAS" % [mini(int(d["vitorias"]), meta), meta], 18, IdleUI.COR_SECUNDARIA, linha)
		if bool(d["coletado"]):
			IdleUI.rotulo("TAÇA DOS %s GANHA!" % fam.to_upper(), 20, IdleUI.COR_OURO, v)
		else:
			var b := IdleUI.botao("COLETAR TAÇA E $" + IdleUI.curto(e.recompensa_desafio()), IdleUI.COR_OURO, 22, 64, v)
			b.disabled = not pronto
			b.pressed.connect(func():
				var r := e.coletar_desafio(fam)
				if r <= 0.0:
					return
				Sons.tocar_ui(self, "flash", -2.0)
				Sons.cascata(self, 6)
				tela.celebrar(3)
				tela.ganho_flutuante(r)
				mudou.emit()
				atualizar())
	if not e.tacas.is_empty():
		var t := IdleUI.rotulo("Taças: %s (%s para sempre)" % [", ".join(e.tacas), texto_bonus("premio", e.bonus_tacas())],
				17, IdleUI.COR_SECUNDARIA, v, "regular")
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 600
