extends Control
## Tela principal (retrato): saldo e dia no topo, abas embaixo. Processa a
## fila a cada segundo para aplicar corridas concluídas com o app aberto.

var dados: Node
var jogador: Node
var _saldo: Label
var _abas: TabContainer
var _todas: Array = []


func _ready() -> void:
	dados = get_node("/root/Dados")
	jogador = get_node("/root/Jogador")
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_saldo.add_theme_font_size_override("font_size", 28)
	raiz.add_child(_saldo)
	_abas = TabContainer.new()
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
	eventos.correr_iniciado.connect(func(): _abas.current_tab = 4)
	if jogador.carro_ativo < 0 and not jogador.garagem.lista().is_empty():
		jogador.carro_ativo = jogador.garagem.lista()[0].uid
	atualizar()

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_processar_fila)
	add_child(timer)
	_mostrar_relatorio(get_node("/root/SaveManager").relatorio_offline, "Enquanto você esteve fora")


func atualizar() -> void:
	_saldo.text = "Saldo %s · Dia %d · %d carros" % [
		Aba.dinheiro(jogador.economia.saldo), jogador.dias, jogador.garagem.lista().size()]
	for a in _todas:
		a.atualizar()


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
