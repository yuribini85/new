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

	_saldo = Label.new()
	_saldo.add_theme_font_size_override("font_size", FONTE_TITULO)
	_saldo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	_saldo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_saldo.clip_text = true
	raiz.add_child(_saldo)
	_abas = TabContainer.new()
	_abas.tabs_visible = false  # navegação pelos botões grandes embaixo
	_abas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(_abas)
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
	add_child(timer)
	var save_manager := get_node("/root/SaveManager")
	if save_manager.aviso != "":
		_sobre.abrir("Save", func(v): _todas[0].rotulo(save_manager.aviso, 0, Color.WHITE, v))
	_mostrar_relatorio(save_manager.relatorio_offline, "Enquanto você esteve fora")


func _navegacao() -> GridContainer:
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	for i in _todas.size():
		var b := Button.new()
		b.text = _todas[i].name
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, ALTURA_BOTAO)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_ir_para.bind(i))
		grade.add_child(b)
		_botoes.append(b)
	_ir_para.call_deferred(0)
	return grade


func _ir_para(i: int) -> void:
	_abas.current_tab = i
	for k in _botoes.size():
		_botoes[k].button_pressed = k == i


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
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.45, 0.5))
	return t


func atualizar() -> void:
	var carro: Carro = jogador.garagem.carro(jogador.carro_ativo)
	_saldo.text = "%s Cr · Dia %d%s" % [Aba.dinheiro(jogador.economia.saldo), jogador.dias,
			" · " + carro.base["nome"] if carro != null else ""]
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
	if rel["corridas"].size() == 1 and rel["erro"] == "" and rel["carros_premio"].is_empty():
		var c: Dictionary = rel["corridas"][0]
		_sobre.avisar("Corrida terminou: %dº de %d%s" % [c["posicao"], c["total"],
				" · +%s Cr" % Aba.dinheiro(c["premio"]) if c["premio"] > 0 else ""], true)
		if c["posicao"] == 1 and not antes_vitorias.has(c["evento_id"]):
			_primeira_vitoria(c)
		return
	_mostrar_relatorio(rel, "Resultado das corridas")


func _notification(what: int) -> void:
	# Volta do segundo plano: aplica o que correu enquanto isso, na hora.
	if what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN] and _sobre != null:
		_processar_fila()


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
	_sobre.abrir(titulo, func(v):
		var corridas: Array = rel["corridas"]
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
						Aba.dinheiro(c["premio"])], Aba.FONTE_PEQUENA + 2, Color.WHITE, detalhes))


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
