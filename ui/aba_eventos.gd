extends Aba

signal correr_iniciado

var _repeticoes := 1
var _aviso := ""


func _init(d: Node, j: Node) -> void:
	super(d, j, "Eventos")


func construir() -> void:
	titulo("Eventos")
	var c := carro_ativo()
	texto("Carro: " + (ficha(c) if c != null else "nenhum — escolha na Garagem"))
	if not jogador.fila.is_empty():
		var f: Dictionary = jogador.fila
		linha("Na fila: %s · faltam %d" % [dados.evento(f["evento_id"])["nome"], f["restantes"]], [
			["Parar", func(): jogador.fila_ctrl.cancelar()],
		])
	if _aviso != "":
		texto(_aviso, Color(1, 0.6, 0.4))
		_aviso = ""
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = "Repetições"
	h.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = _repeticoes
	spin.value_changed.connect(func(v): _repeticoes = int(v))
	h.add_child(spin)
	conteudo.add_child(h)
	separador()
	for ev in dados.lista("eventos"):
		var motivos := [] if c == null else Elegibilidade.motivos(c, ev["restricoes"], jogador.licencas)
		var premio := dinheiro(int(ev["premios"][0])) if not ev["premios"].is_empty() else "0"
		var desc := "%s · %s · %d voltas · %s · 1º %s" % [ev["nome"], dados.pista(ev["pista"]).id, ev["voltas"], ev["condicao"], premio]
		if ev.get("carro_premio") != null and not jogador.vitorias.has(ev["id"]):
			desc += " + carro"
		if not motivos.is_empty():
			desc += "\n  " + ", ".join(motivos)
		linha(desc, [
			["Correr", _correr.bind(ev["id"]), c != null and motivos.is_empty() and jogador.fila.is_empty()],
		])


func _correr(evento_id: String) -> void:
	_aviso = jogador.fila_ctrl.iniciar(evento_id, jogador.carro_ativo, _repeticoes, Time.get_unix_time_from_system())
	if _aviso == "":
		correr_iniciado.emit()
