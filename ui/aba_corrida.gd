extends VBoxContainer
## Corrida ao vivo: mostra a corrida em andamento da fila no tempo real.
## O resultado já está decidido pela simulação; a tela só o reproduz.

signal mudou

var dados: Node
var jogador: Node
var _visual: CorridaVisual
var _info: Label
var _classificacao: Label
var _semente_mostrada := 0
var _nomes := {}  # id do participante -> nome do carro


func _init(d: Node, j: Node) -> void:
	dados = d
	jogador = j
	name = "Corrida"
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)
	_visual = CorridaVisual.new()
	_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_visual.custom_minimum_size = Vector2(0, 520)
	add_child(_visual)
	_classificacao = Label.new()
	_classificacao.add_theme_font_size_override("font_size", 22)
	add_child(_classificacao)


func atualizar() -> void:
	_semente_mostrada = 0


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or jogador.fila_ctrl == null:
		return
	var f: Dictionary = jogador.fila
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
		_info.text = "%s · %d voltas · %s · faltam %d" % [ev["nome"], ev["voltas"], ev["condicao"], f["restantes"]]
	_visual.tempo = clampf(agora - float(f["inicio"]), 0.0, _visual.duracao())
	var linhas := []
	var ordem := _visual.ordem()
	for i in ordem.size():
		linhas.append("%d. %s" % [i + 1, _nomes.get(ordem[i], ordem[i])])
	_classificacao.text = "\n".join(linhas)
