extends Control
## Tela principal (retrato): saldo e dia no topo, abas embaixo. Processa a
## fila a cada segundo para aplicar corridas concluídas com o app aberto.

var dados: Node
var jogador: Node
var _saldo: Label
var _abas: TabContainer
var _todas: Array = []
var _botoes: Array = []
var _sobre: Sobreposicao
var _voltar: Button
var _ao_vivo: Button
## Destinos da barra de baixo: [rótulo, índice da aba]. Oficina e Corrida são
## telas internas (de Garagem e Competições), abertas pelo caminho do jogo.
const DESTINOS := [["Garagem", 0], ["Mercado", 1], ["Competições", 3], ["Carreira", 5]]
const PAI := {2: 0, 4: 3}
const NOME_PAI := {2: "‹ Garagem", 4: "‹ Competições"}
## Objetivo atual da carreira; quando avança, o jogador é avisado.
var _objetivo := -1

## Tamanhos para tela de celular em retrato (viewport 720 de largura).
const FONTE := 30
const FONTE_TITULO := 38
const ALTURA_BOTAO := 76


func _ready() -> void:
	dados = get_node("/root/Dados")
	jogador = get_node("/root/Jogador")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_simbolos()
	Preferencias.carregar()
	theme = _tema()
	var fundo := ColorRect.new()
	fundo.color = Color(0.09, 0.1, 0.12)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 16)
	add_child(margem)
	var raiz := VBoxContainer.new()
	margem.add_child(raiz)

	if jogador.economia == null or jogador.fila_ctrl == null:
		_tela_pendencias(raiz)
		return

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 12)
	raiz.add_child(topo)
	_voltar = Button.new()
	_voltar.flat = true
	_voltar.custom_minimum_size = Vector2(0, 56)
	_voltar.add_theme_color_override("font_color", Aba.COR_INFO.lightened(0.2))
	_voltar.pressed.connect(func(): _ir_para(PAI.get(_abas.current_tab, 0)))
	topo.add_child(_voltar)
	_saldo = Label.new()
	_saldo.add_theme_font_size_override("font_size", FONTE_TITULO)
	_saldo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saldo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_saldo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_saldo.clip_text = true
	topo.add_child(_saldo)
	_abas = TabContainer.new()
	_abas.tabs_visible = false  # navegação pelos botões grandes embaixo
	# Moldura sem layout: o tamanho mínimo das abas não passa para a tela. Se
	# algum conteúdo pedir mais largura que o celular, ele é cortado dentro da
	# aba, mas o topo e a navegação nunca saem da tela.
	var moldura := Control.new()
	moldura.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moldura.clip_contents = true
	raiz.add_child(moldura)
	_abas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moldura.add_child(_abas)
	var eventos := preload("res://ui/aba_eventos.gd").new(dados, jogador)
	_todas = [
		preload("res://ui/aba_garagem.gd").new(dados, jogador),
		preload("res://ui/aba_loja.gd").new(dados, jogador),
		preload("res://ui/aba_oficina.gd").new(dados, jogador),
		eventos,
		preload("res://ui/aba_corrida.gd").new(dados, jogador),
		preload("res://ui/aba_licencas.gd").new(dados, jogador),
	]
	for a in _todas:
		_abas.add_child(a)
		a.mudou.connect(atualizar)
		a.ir_para.connect(func(i):
			_ir_para(i)
			atualizar())
	eventos.correr_iniciado.connect(func(): _ir_para(4))
	_todas[4].pular.connect(func():
		jogador.fila_ctrl.adiantar(Time.get_unix_time_from_system())
		_processar_fila())
	_ao_vivo = Button.new()
	_ao_vivo.custom_minimum_size = Vector2(0, 64)
	_ao_vivo.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ao_vivo.clip_text = true
	_ao_vivo.add_theme_font_size_override("font_size", 25)
	var sb_vivo := StyleBoxFlat.new()
	sb_vivo.bg_color = Color(0.1, 0.34, 0.2)
	sb_vivo.set_corner_radius_all(10)
	sb_vivo.set_content_margin_all(10)
	for estado in ["normal", "hover", "pressed", "focus"]:
		_ao_vivo.add_theme_stylebox_override(estado, sb_vivo)
	_ao_vivo.pressed.connect(func(): _ir_para(4))
	raiz.add_child(_ao_vivo)
	raiz.add_child(_navegacao())
	_sobre = Sobreposicao.new()
	add_child(_sobre)
	for a in _todas:
		a.aviso.connect(_sobre.avisar)
		a.painel.connect(_sobre.abrir)
	if jogador.carro_ativo < 0 and not jogador.garagem.lista().is_empty():
		jogador.carro_ativo = jogador.garagem.lista()[0].uid
	atualizar()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_processar_fila)
	timer.timeout.connect(_atualizar_ao_vivo)
	add_child(timer)
	var save_manager := get_node("/root/SaveManager")
	if save_manager.aviso != "":
		_sobre.abrir("Save", func(v): _todas[0].rotulo(save_manager.aviso, 0, Color.WHITE, v))
	_mostrar_relatorio(save_manager.relatorio_offline, "Enquanto você esteve fora")


func _navegacao() -> HBoxContainer:
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 8)
	for d in DESTINOS:
		var b := Button.new()
		b.text = d[0]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_ir_para.bind(d[1]))
		barra.add_child(b)
		_botoes.append(b)
	_ir_para.call_deferred(0)
	return barra


func _ir_para(i: int) -> void:
	_abas.current_tab = i
	var destino: int = PAI.get(i, i)
	for k in _botoes.size():
		_botoes[k].button_pressed = DESTINOS[k][1] == destino
	_voltar.text = NOME_PAI.get(i, "")
	_voltar.visible = PAI.has(i)
	_atualizar_ao_vivo()


## Faixa "ao vivo" acima da navegação enquanto a fila corre (fora da Corrida).
func _atualizar_ao_vivo() -> void:
	var f: Dictionary = jogador.fila
	_ao_vivo.visible = not f.is_empty() and not _abas.current_tab in [3, 4]
	if not _ao_vivo.visible:
		return
	var dur: float = jogador.fila_ctrl.duracao_atual()
	var falta := maxf(dur - (Time.get_unix_time_from_system() - float(f["inicio"])), 0.0)
	_ao_vivo.text = "●  AO VIVO · %s · %d:%02d   Assistir ›" % [dados.evento(f["evento_id"]).get("nome", ""),
			int(falta) / 60, int(falta) % 60]


## A fonte padrão do Godot não tem ✓ ✗ ★ → ⚠ ■; no navegador não há fonte do
## sistema para cobrir, e eles viravam quadrados. Reserva com esses glifos.
static func _simbolos() -> void:
	var f := ThemeDB.fallback_font
	var reserva: Font = load("res://ui/fontes/simbolos.ttf")
	if reserva != null and not reserva in f.fallbacks:
		f.fallbacks = f.fallbacks + [reserva]


func _tema() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONTE
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.2, 0.22, 0.26)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(12)
	var apertado := normal.duplicate()
	apertado.bg_color = Color(0.95, 0.75, 0.15)
	var desabilitado := normal.duplicate()
	desabilitado.bg_color = Color(0.14, 0.15, 0.17)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", apertado)
	t.set_stylebox("hover_pressed", "Button", apertado)
	t.set_stylebox("disabled", "Button", desabilitado)
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.1, 0.1))
	t.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.1, 0.1))
	t.set_color("font_disabled_color", "Button", Color(0.64, 0.65, 0.7))
	return t


func atualizar() -> void:
	_saldo.text = "%s Cr" % Aba.dinheiro(jogador.economia.saldo)
	_saldo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	_atualizar_ao_vivo()
	for a in _todas:
		a.atualizar()
	var objetivos := Objetivos.lista(jogador, dados)
	var atual := Objetivos.atual(objetivos)
	if _objetivo >= 0 and atual > _objetivo and _sobre != null:
		var proximo: String = objetivos[atual]["texto"] if atual < objetivos.size() else "todos cumpridos!"
		_sobre.avisar("Objetivo cumprido: %s. Próximo: %s" % [objetivos[atual - 1]["texto"], proximo])
	_objetivo = atual
	# Toda ação do jogador passa por aqui: salvar já. No navegador não há aviso
	# confiável de fechamento, e uma compra não pode se perder.
	get_node("/root/SaveManager").salvar()


func _processar_fila() -> void:
	if jogador.fila.is_empty():
		return
	var antes_vitorias: Dictionary = jogador.vitorias.duplicate()
	var rel: Dictionary = jogador.fila_ctrl.processar(Time.get_unix_time_from_system())
	if rel["corridas"].is_empty() and rel["erro"] == "":
		return
	atualizar()
	get_node("/root/SaveManager").salvar()
	# Uma corrida terminando com o app aberto: aviso curto e a tela de Corrida
	# mostra o resultado. Várias (voltou do segundo plano), erro ou carro-prêmio:
	# relatório.
	if rel["corridas"].size() == 1 and rel["erro"] == "":
		_resultado(rel["corridas"][0], not antes_vitorias.has(rel["corridas"][0]["evento_id"]))
		return
	_mostrar_relatorio(rel, "Resultado das corridas")


func _notification(what: int) -> void:
	# Volta do segundo plano: aplica o que correu enquanto isso, na hora.
	if what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and _sobre != null:
		_processar_fila()


## Resultado de uma corrida terminada com o app aberto: posição em destaque,
## recompensa e a próxima decisão.
func _resultado(c: Dictionary, primeira: bool) -> void:
	var g: Aba = _todas[0]
	var venceu: bool = c["posicao"] == 1
	var ev: Dictionary = dados.evento(c["evento_id"])
	var continua: bool = not jogador.fila.is_empty()
	var botoes := []
	if continua:
		botoes = [["Assistir a próxima", func(): _ir_para(4)], ["Fechar", func(): pass]]
	else:
		botoes = [["Repetir", func():
				var m: String = jogador.fila_ctrl.iniciar(c["evento_id"], c["uid"], 1, Time.get_unix_time_from_system())
				if m != "":
					_sobre.avisar("Não deu para correr: %s." % m, false)
				else:
					_ir_para(4)
				atualizar()],
			["Preparar", func():
				jogador.carro_ativo = c["uid"]
				_ir_para(2)
				atualizar()],
			["Outra prova", func(): _ir_para(3)]]
		var carro_corrida: Carro = jogador.garagem.carro(c["uid"])
		if not venceu and carro_corrida != null:
			# Derrota: comparar preparações antes de gastar outra corrida inteira.
			botoes.insert(1, ["Testar preparação", func(): g.testar_preparacao(c["evento_id"], carro_corrida)])
		# A ação em destaque (primeira) é a que leva ao próximo objetivo.
		var alvo_obj: Array = Objetivos.lista(jogador, dados)
		var i_obj := Objetivos.atual(alvo_obj)
		var aba_obj: int = alvo_obj[i_obj]["aba"] if i_obj < alvo_obj.size() else -1
		var primeiro := 0
		if aba_obj == Aba.OFICINA or (not venceu and aba_obj != Aba.EVENTOS):
			primeiro = 1
		elif aba_obj == Aba.EVENTOS and venceu:
			primeiro = 2
		if primeiro > 0:
			var b = botoes[primeiro]
			botoes.remove_at(primeiro)
			botoes.push_front(b)
	var meu: Carro = jogador.garagem.carro(c["uid"])
	var tabela: Array = c.get("tabela", [])
	var objetivos := Objetivos.lista(jogador, dados)
	var obj := Objetivos.atual(objetivos)
	_sobre.abrir("VITÓRIA!" if venceu else "Resultado", func(v):
		if meu != null:
			v.add_child(Estudio.imagem(meu.base, CarroBloco.cor_do_carro(meu), Vector2(0, 170)))
		var pos := Label.new()
		pos.text = "%dº de %d" % [c["posicao"], c["total"]]
		pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pos.add_theme_font_size_override("font_size", 72)
		pos.add_theme_color_override("font_color", Aba.COR_DESTAQUE if venceu else Color.WHITE)
		v.add_child(pos)
		var nome_ev := g.rotulo(ev.get("nome", ""), Aba.FONTE_PEQUENA + 3, Aba.COR_SECUNDARIA, v)
		nome_ev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if tabela.size() >= 2:
			var t0: float = tabela[0]["tempo"]
			var dif := g.rotulo("%.1f s à frente do 2º" % (tabela[1]["tempo"] - t0) if venceu
					else "%.1f s atrás do vencedor" % (c["tempo_jogador"] - t0), Aba.FONTE_PEQUENA + 3, Color.WHITE, v)
			dif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_podio(v, tabela, c)
		if c["premio"] > 0:
			var saldo := g.rotulo("%s → %s Cr  (+%s)" % [Aba.dinheiro(jogador.economia.saldo - c["premio"]),
					Aba.dinheiro(jogador.economia.saldo), Aba.dinheiro(c["premio"])], 30, Aba.COR_BOM, v)
			saldo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var marcos := []
		if venceu and primeira:
			marcos.append(["PRIMEIRA VITÓRIA NESTA PROVA", Aba.COR_DESTAQUE])
		if c.get("recorde", false) and not c.get("anterior", {}).is_empty():
			marcos.append(["RECORDE PESSOAL", Aba.COR_BOM])
		if not c.get("anterior", {}).is_empty():
			var dp: int = int(c["anterior"]["ultima_pos"]) - int(c["posicao"])
			if dp != 0:
				marcos.append(["%s %d posiç%s desde a última vez" % ["subiu" if dp > 0 else "caiu", absi(dp),
						"ão" if absi(dp) == 1 else "ões"], Aba.COR_BOM if dp > 0 else Aba.COR_RUIM])
		g.selos(marcos, v)
		if c.get("carro_premio_uid", -1) > 0:
			var cp: Carro = jogador.garagem.carro(c["carro_premio_uid"])
			if cp != null:
				var vc := g.cartao(Aba.COR_DESTAQUE, v)
				g.rotulo("CARRO-PRÊMIO: %s" % cp.base["nome"], Aba.FONTE_PEQUENA + 2, Aba.COR_DESTAQUE, vc)
				vc.add_child(Estudio.imagem(cp.base, CarroBloco.cor_do_carro(cp), Vector2(0, 170)))
		if obj < objetivos.size():
			var lo := g.rotulo("Objetivo %d/%d: %s" % [obj + 1, objetivos.size(), objetivos[obj]["texto"]], Aba.FONTE_PEQUENA + 2,
					Aba.COR_INFO.lightened(0.3), v)
			lo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not venceu:
			var dica := g.rotulo("Em Competições › Corrida: por que perdeu e o que ajuda.", Aba.FONTE_PEQUENA,
					Aba.COR_SECUNDARIA, v)
			dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER, botoes)


## Pódio dos três primeiros: degraus de alturas diferentes, o jogador em ouro.
func _podio(v: VBoxContainer, tabela: Array, c: Dictionary) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	for pos in [2, 1, 3]:
		if pos > tabela.size():
			continue
		var id: String = tabela[pos - 1]["id"]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		var nome := Label.new()
		nome.text = "Você" if id == "jogador" else Carreira.nome_piloto(c["evento_id"], id)
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_font_size_override("font_size", 23)
		nome.add_theme_color_override("font_color", Aba.COR_DESTAQUE if id == "jogador" else Color.WHITE)
		col.add_child(nome)
		var degrau := PanelContainer.new()
		degrau.custom_minimum_size = Vector2(0, {1: 90, 2: 64, 3: 46}[pos])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Aba.COR_DESTAQUE.darkened(0.15) if id == "jogador" else Color(0.26, 0.28, 0.33)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		degrau.add_theme_stylebox_override("panel", sb)
		var n := Label.new()
		n.text = "%dº" % pos
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		n.add_theme_font_size_override("font_size", 30)
		n.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1) if id == "jogador" else Color.WHITE)
		degrau.add_child(n)
		col.add_child(degrau)
		h.add_child(col)


func _primeira_vitoria(c: Dictionary) -> void:
	var g: Aba = _todas[0]
	_sobre.abrir("Primeira vitória!", func(v):
		g.rotulo(dados.evento(c["evento_id"]).get("nome", ""), 30, Aba.COR_DESTAQUE, v)
		g.rotulo("Você venceu esta prova pela primeira vez. Prêmio: +%s Cr." % Aba.dinheiro(c["premio"]), 0, Color.WHITE, v)
		g.rotulo("Próximo passo: tente uma prova que paga mais, ou prepare o carro na Oficina.", Aba.FONTE_PEQUENA + 2,
				Aba.COR_SECUNDARIA, v))


## Relatório de várias corridas (offline ou segundo plano): resumo e, sob
## pedido, a lista de cada corrida.
func _mostrar_relatorio(rel: Dictionary, titulo: String) -> void:
	if rel.is_empty() or (rel["corridas"].is_empty() and rel["erro"] == ""):
		return
	var g: Aba = _todas[0]
	var objetivos := Objetivos.lista(jogador, dados)
	var i_obj := Objetivos.atual(objetivos)
	var botoes := []
	if i_obj < objetivos.size():
		var aba_obj: int = objetivos[i_obj]["aba"]
		botoes = [[objetivos[i_obj]["botao"], func(): _ir_para(aba_obj)], ["Fechar", func(): pass]]
	_sobre.abrir(titulo, func(v):
		var corridas: Array = rel["corridas"]
		# Primeiro o plano: objetivo, dinheiro e o próximo obstáculo.
		var vp := g.cartao(Aba.COR_INFO, v)
		if i_obj < objetivos.size():
			g.rotulo("OBJETIVO %d/%d" % [i_obj + 1, objetivos.size()], Aba.FONTE_PEQUENA, Aba.COR_INFO, vp)
			g.rotulo(objetivos[i_obj]["texto"], 30, Color.WHITE, vp)
		g.rotulo("Saldo: %s Cr" % Aba.dinheiro(jogador.economia.saldo), Aba.FONTE_PEQUENA + 3, Aba.COR_DESTAQUE, vp)
		var obstaculo := Objetivos.proximo_obstaculo(jogador, dados)
		if obstaculo != "":
			g.rotulo(obstaculo, Aba.FONTE_PEQUENA + 2, Color.WHITE, vp)
		for cid in jogador.desejos:
			var p := Usados.proxima(dados.carro(cid), jogador.dias, jogador.usados_vendidos)
			if not p.is_empty() and p["inicio"] <= jogador.dias:
				g.rotulo("♥ %s à venda nos usados por %s Cr" % [dados.carro(cid)["nome"], Aba.dinheiro(p["preco"])],
						Aba.FONTE_PEQUENA + 2, Aba.COR_DESTAQUE, vp)
		if not corridas.is_empty():
			var vitorias := corridas.filter(func(c): return c["posicao"] == 1).size()
			var melhor: int = corridas.map(func(c): return c["posicao"]).min()
			var resumo := g.cartao(Aba.COR_BOM, v)
			g.rotulo("%d corrida%s · %d vitória%s · melhor %dº" % [corridas.size(), "" if corridas.size() == 1 else "s",
					vitorias, "" if vitorias == 1 else "s", melhor], 0, Color.WHITE, resumo)
			g.rotulo("+%s Cr em prêmios" % Aba.dinheiro(rel["premio_total"]), 34, Aba.COR_DESTAQUE, resumo)
		for uid in rel["carros_premio"]:
			var cp: Carro = jogador.garagem.carro(uid)
			if cp != null:
				var vc := g.cartao(Aba.COR_DESTAQUE, v)
				g.rotulo("CARRO-PRÊMIO", Aba.FONTE_PEQUENA, Aba.COR_DESTAQUE, vc)
				var h := g.fileira(vc)
				h.add_child(g.icone_carro(cp.base))
				g.rotulo(cp.base["nome"], 30, Color.WHITE, h)
				g.rotulo("Já está na sua garagem.", Aba.FONTE_PEQUENA, Aba.COR_SECUNDARIA, vc)
		if rel["erro"] != "":
			var ve := g.cartao(Aba.COR_RUIM, v)
			g.rotulo("A fila parou: " + rel["erro"], 0, Aba.COR_RUIM, ve)
		if rel.get("tempo_perdido_s", 0.0) > 0.0:
			var teto: float = float(dados.carreira().get("teto_offline_s", 0.0))
			var vt := g.cartao(Aba.COR_INFO, v)
			g.rotulo("Você ficou fora mais que o limite de %s. %s além disso não contaram; a fila continuou de onde parou." % [
					_duracao(teto), _duracao(rel["tempo_perdido_s"])], Aba.FONTE_PEQUENA + 2, Color.WHITE, vt)
		if corridas.size() > 1:
			var detalhes := VBoxContainer.new()
			detalhes.visible = false
			var b := Button.new()
			b.text = "Ver cada corrida"
			b.custom_minimum_size = Vector2(0, 68)
			b.pressed.connect(func():
				detalhes.visible = not detalhes.visible
				b.text = "Esconder" if detalhes.visible else "Ver cada corrida")
			v.add_child(b)
			v.add_child(detalhes)
			for c in corridas:
				g.rotulo("%s · %dº · %s Cr" % [dados.evento(c["evento_id"]).get("nome", ""), c["posicao"],
						Aba.dinheiro(c["premio"])], Aba.FONTE_PEQUENA + 2, Color.WHITE, detalhes), botoes)


static func _duracao(s: float) -> String:
	if s >= 3600.0:
		return "%d h %02d min" % [int(s) / 3600, (int(s) % 3600) / 60]
	return "%d min" % maxi(1, int(s) / 60)


func _tela_pendencias(raiz: VBoxContainer) -> void:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var linhas := ["Balanceamento incompleto — o jogo não pode começar.", ""]
	for e in dados.erros():
		linhas.append("ERRO: " + e)
	for p in dados.pendencias():
		linhas.append("• " + p)
	linhas.append("")
	linhas.append("Para ver as telas com dados de teste: godot -- --dados=res://tests/fixtures/")
	l.text = "\n".join(linhas)
	raiz.add_child(l)
