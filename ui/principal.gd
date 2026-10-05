extends Control
## Tela principal (retrato): saldo e dia no topo, abas embaixo. Processa a
## fila a cada segundo para aplicar corridas concluídas com o app aberto.

var dados: Node
var jogador: Node
var _saldo: Label
var _abas: TabContainer
var _todas: Array = []
var _botoes: Array = []

## Tamanhos para tela de celular em retrato (viewport 720 de largura).
const FONTE := 30
const FONTE_TITULO := 38
const ALTURA_BOTAO := 76


func _ready() -> void:
	dados = get_node("/root/Dados")
	jogador = get_node("/root/Jogador")
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	eventos.correr_iniciado.connect(func(): _ir_para(4))
	_todas[4].pular.connect(func():
		jogador.fila_ctrl.adiantar(Time.get_unix_time_from_system())
		_processar_fila())
	raiz.add_child(_navegacao())
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
		var d := AcceptDialog.new()
		d.title = "Save"
		d.dialog_text = save_manager.aviso
		add_child(d)
		d.popup_centered()
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
	_saldo.text = "Saldo %s · Dia %d · %d carros" % [
		Aba.dinheiro(jogador.economia.saldo), jogador.dias, jogador.garagem.lista().size()]
	for a in _todas:
		a.atualizar()
	# Toda ação do jogador passa por aqui: salvar já. No navegador não há aviso
	# confiável de fechamento, e uma compra não pode se perder.
	get_node("/root/SaveManager").salvar()


func _processar_fila() -> void:
	if jogador.fila.is_empty():
		return
	var rel: Dictionary = jogador.fila_ctrl.processar(Time.get_unix_time_from_system())
	if not rel["corridas"].is_empty() or rel["erro"] != "":
		atualizar()
		get_node("/root/SaveManager").salvar()
		if rel["erro"] != "" or not rel["carros_premio"].is_empty():
			_mostrar_relatorio(rel, "Resultado")


func _mostrar_relatorio(rel: Dictionary, titulo: String) -> void:
	if rel.is_empty() or (rel["corridas"].is_empty() and rel["erro"] == ""):
		return
	var linhas := []
	for c in rel["corridas"]:
		linhas.append("%s: %dº · %s" % [dados.evento(c["evento_id"])["nome"], c["posicao"], Aba.dinheiro(c["premio"])])
	if linhas.size() > 10:
		linhas = linhas.slice(0, 5) + ["… mais %d corridas" % (linhas.size() - 5)]
	linhas.append("Total: %s" % Aba.dinheiro(rel["premio_total"]))
	for uid in rel["carros_premio"]:
		linhas.append("Carro-prêmio: %s" % jogador.garagem.carro(uid).base["nome"])
	if rel["erro"] != "":
		linhas.append("Fila parada: " + rel["erro"])
	if rel.get("tempo_perdido_s", 0.0) > 0.0:
		linhas.append("Tempo além do limite offline não contou.")
	var d := AcceptDialog.new()
	d.title = titulo
	d.dialog_text = "\n".join(linhas)
	add_child(d)
	d.popup_centered()


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
