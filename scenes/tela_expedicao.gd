extends CanvasLayer
## Tela de expedição — lista de regiões, lançar, status e relatório.
## especificacao_tecnica_v1.md #33: "tela cheia ao voltar" — simplificado aqui como
## painel; o botão de anúncio para recuperar 1 morto fica de fora (sem monetização
## no primeiro build, CLAUDE.md).

@onready var _titulo: Label = $Painel/VBox/Titulo
@onready var _lista: VBoxContainer = $Painel/VBox/Scroll/Lista

var _timer: Timer


func _ready() -> void:
	Expedicoes.expedicao_iniciada.connect(func(_r): _atualizar())
	Expedicoes.expedicao_concluida.connect(func(_r): _atualizar())
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_atualizar)
	add_child(_timer)
	_timer.start()
	_atualizar()


func _atualizar() -> void:
	for c in _lista.get_children():
		c.queue_free()

	if Expedicoes.atual != null:
		_titulo.text = "Expedição em curso"
		var exp: Expedicao = Expedicoes.atual
		var restante := (exp.inicio_unix + exp.duracao_seg) - int(Time.get_unix_time_from_system())
		var l := Label.new()
		l.text = "%s · volta em %ds · equipe: %s" % [exp.regiao_id, maxi(0, restante), ", ".join(exp.equipe)]
		_lista.add_child(l)
		return

	if not Expedicoes.ultimo_relatorio.is_empty():
		_titulo.text = "Relatório da expedição"
		var rel := Expedicoes.ultimo_relatorio
		var l := Label.new()
		var mortos: Array = rel.get("mortos", [])
		var texto := "%s\nfôlego +%s\n%d foram, %d voltaram, %d não voltaram" % [
			rel.get("regiao_nome", ""), rel.get("folego_ganho", 0),
			rel.get("equipe", []).size(), rel.get("equipe", []).size() - mortos.size(), mortos.size(),
		]
		l.text = texto
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_lista.add_child(l)

		var botao_ok := Button.new()
		botao_ok.text = "OK"
		botao_ok.pressed.connect(func(): Expedicoes.ultimo_relatorio = {}; _atualizar())
		_lista.add_child(botao_ok)
		return

	_titulo.text = "Expedições"
	for r in Expedicoes.regioes():
		var linha := HBoxContainer.new()
		var info := Label.new()
		var disponivel: bool = r["tier"] <= Expedicoes.tier_maximo_liberado()
		info.text = "%s · %ds · %d aldeões · risco %d%% · %s" % [
			r["nome"], r["duracao_seg"], r["aldeoes"], int(r["risco"] * 100),
			("disponível" if disponivel else "requer mina tier %d" % r["tier"]),
		]
		linha.add_child(info)

		if disponivel:
			var botao := Button.new()
			botao.text = "Enviar"
			botao.pressed.connect(_on_enviar_pressed.bind(r["id"]))
			linha.add_child(botao)

		_lista.add_child(linha)


func _on_enviar_pressed(regiao_id: String) -> void:
	var r := Expedicoes.regiao(regiao_id)
	var necessario := int(r.get("aldeoes", 0))
	var equipe: Array = []
	for id in Populacao.orfaos:
		if equipe.size() >= necessario:
			break
		if Populacao.orfaos[id].estado == Orfao.Estado.ADULTO_OCIOSO:
			equipe.append(id)

	if equipe.size() < necessario:
		return  # sem aldeões ociosos suficientes; "preencher automático" simplificado

	Expedicoes.iniciar(regiao_id, equipe)
