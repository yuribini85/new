extends VBoxContainer
## Corrida ao vivo: mostra a corrida em andamento da fila no tempo real.
## O resultado já está decidido pela simulação; a tela só o reproduz.

signal mudou
## Pede para encerrar a corrida em andamento agora (fase de testes da demo).
signal pular

## Botão "Ver resultado" para testar a demo sem esperar a corrida em tempo
## real. Desligar antes de publicar: o jogo é idle, a espera é parte dele.
const PERMITIR_PULAR := true

var dados: Node
var jogador: Node
var _visual: CorridaVisual
var _info: Label
var _classificacao: RichTextLabel
var _semente_mostrada := 0
var _nomes := {}  # id do participante -> nome do carro
var _painel: VBoxContainer
var _analise := {}  # {"dia": int, "base": float, "opcoes": [...]}
var _em_andamento := false


func _init(d: Node, j: Node) -> void:
	dados = d
	jogador = j
	name = "Corrida"
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_visual = CorridaVisual.new()
	_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_visual.custom_minimum_size = Vector2(0, 420)
	add_child(_visual)
	_classificacao = RichTextLabel.new()
	_classificacao.bbcode_enabled = true
	_classificacao.fit_content = true
	_classificacao.scroll_active = false
	add_child(_classificacao)
	_painel = VBoxContainer.new()
	add_child(_painel)


func atualizar() -> void:
	_semente_mostrada = 0
	_construir_painel()


## Painel de baixo: "Ver resultado" durante a corrida e o relatório da última.
func _construir_painel() -> void:
	for c in _painel.get_children():
		c.queue_free()
	_em_andamento = not jogador.fila.is_empty()
	if _em_andamento and PERMITIR_PULAR:
		_botao("Ver resultado (teste)", func(): pular.emit())
	var u: Dictionary = jogador.ultima_corrida
	if u.is_empty():
		return
	var ev: Dictionary = dados.evento(u["evento_id"])
	var carreira: Carreira = jogador.carreira
	var seu: Carro = jogador.garagem.carro(u["uid"])
	_painel.add_child(HSeparator.new())
	var texto := "Última: %s\n%dº de %d" % [ev.get("nome", ""), u["posicao"], u["total"]]
	if u["premio"] > 0:
		texto += " · +%s Cr" % Aba.dinheiro(u["premio"])
	if u["posicao"] > 1:
		var venc := carreira.carro_participante(u["vencedor"])
		texto += "\n%.1f s atrás de %s" % [u["tempo_jogador"] - u["tempo_vencedor"], carreira.nome_participante(u["vencedor"], u["uid"])]
		if not venc.is_empty() and seu != null:
			var a := seu.atributos_efetivos(ev.get("condicao", "seco"))
			texto += "\nEle: %d cv · %d kg   Você: %d cv · %d kg" % [venc["potencia"], venc["peso"], a["potencia"], a["peso"]]
	_rotulo(texto)
	if u["posicao"] > 1 and seu != null:
		if _analise.get("dia", -1) != u["dia"]:
			_botao("O que ajuda?", _analisar)
		elif _analise["opcoes"].is_empty():
			_rotulo("Nada que caiba no seu saldo melhora a posição média (%.1f). Tente outro evento ou junte prêmios." % _analise["base"])
		else:
			_rotulo("Posição média hoje: %.1f. Com:" % _analise["base"])
			for o in _analise["opcoes"]:
				var h := HBoxContainer.new()
				var l := Label.new()
				l.text = "%s → %.1f" % [o["nome"], o["media"]]
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(l)
				var b := Button.new()
				b.text = "Instalar" if o["preco"] == 0 else Aba.dinheiro(o["preco"])
				b.custom_minimum_size = Vector2(170, 72)
				b.pressed.connect(_comprar.bind(o, seu))
				h.add_child(b)
				_painel.add_child(h)
	if not _em_andamento and seu != null:
		_botao("Correr de novo", _correr_de_novo)


func _analisar() -> void:
	for c in _painel.get_children():
		c.queue_free()
	_rotulo("Analisando…")
	# Deixa a tela mostrar o aviso antes das simulações.
	await get_tree().process_frame
	await get_tree().process_frame
	var u: Dictionary = jogador.ultima_corrida
	_analise = Mecanico.analisar(jogador.carreira, u["evento_id"], u["uid"])
	_analise["dia"] = u["dia"]
	_construir_painel()


func _comprar(o: Dictionary, carro: Carro) -> void:
	if o["tipo"] == "peca":
		jogador.concessionaria.comprar_peca(carro, o["item"])
	else:
		jogador.concessionaria.comprar_pneu(carro, o["item"])
	_analise = {}
	mudou.emit()


func _correr_de_novo() -> void:
	var u: Dictionary = jogador.ultima_corrida
	jogador.fila_ctrl.iniciar(u["evento_id"], u["uid"], 1, Time.get_unix_time_from_system())
	mudou.emit()


func _rotulo(t: String) -> void:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_painel.add_child(l)


func _botao(t: String, acao: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(acao)
	_painel.add_child(b)


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or jogador.fila_ctrl == null:
		return
	var f: Dictionary = jogador.fila
	if f.is_empty() != not _em_andamento:
		_construir_painel()
	if f.is_empty():
		_visual.limpar()
		_semente_mostrada = 0
		_info.text = "Nenhuma corrida na fila. Escolha um evento."
		_classificacao.text = ""
		return
	var agora := Time.get_unix_time_from_system()
	if f["semente"] != _semente_mostrada:
		var c: Dictionary = jogador.fila_ctrl.corrida_atual(agora)
		if c.is_empty():
			return
		var ev: Dictionary = dados.evento(f["evento_id"])
		_visual.mostrar(dados.pista(ev["pista"]), c["resultado"], {"jogador": Color(1.0, 0.85, 0.2)})
		_semente_mostrada = f["semente"]
		_nomes = {"jogador": "VOCÊ · " + jogador.garagem.carro(f["uid"]).base["nome"]}
		for i in ev["adversarios"].size():
			var adv: Dictionary = ev["adversarios"][i]
			_nomes["adv%d_%s" % [i, adv["carro"]]] = dados.carro(adv["carro"])["nome"]
		_info.text = "%s · %s · %d voltas · faltam %d" % [ev["nome"], Aba.nome_pista(ev["pista"]), ev["voltas"], f["restantes"]]
	_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
	var linhas := []
	var ordem := _visual.ordem()
	for i in ordem.size():
		var id: String = ordem[i]
		var nome: String = _nomes.get(id, id)
		if id == "jogador":
			nome = "[b]%s[/b]" % nome
		linhas.append("%d [color=#%s]■[/color] %s" % [i + 1, _visual.cor_de(id).to_html(false), nome])
	_classificacao.text = "\n".join(linhas)
