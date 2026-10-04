extends SceneTree
## Matriz de progressão: posição de cada carro de data/carros.json (de
## fábrica, pneu de fábrica, piloto do jogador) em cada evento em que ele
## pode correr, ignorando licença. Serve para revisar o balanceamento.
## Uso: godot --headless --script res://tools/simular_progressao.gd [-- --semente=1]

var _feito := false


func _process(_delta: float) -> bool:
	if not _feito:
		_feito = true
		_rodar()
		quit()
	return false


func _rodar() -> void:
	var dados: Node = root.get_node("Dados")
	var jogador: Node = root.get_node("Jogador")
	var semente := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--semente="):
			semente = int(arg.trim_prefix("--semente="))
	var carros: Array = dados.lista("carros")
	carros.sort_custom(func(a, b): return a["potencia"] < b["potencia"])
	var cab := "%-40s" % "evento"
	for c in carros:
		cab += " %6s" % c["id"].split("_")[1].substr(0, 6)
	print(cab)
	for ev in dados.lista("eventos"):
		var linha := "%-40s" % ev["nome"].substr(0, 40)
		for c in carros:
			jogador.novo_jogo(dados.economia(), dados.pneu)
			jogador.licencas = ["B", "A"]
			var uid: int = jogador.garagem.adicionar(Carro.new(c))
			jogador.garagem.carro(uid).adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
			var r: Dictionary = Carreira.new(dados, jogador).preparar(ev["id"], uid, semente, false)
			if r.has("erro"):
				linha += " %6s" % "-"
			else:
				var cl: Array = r["resultado"]["classificacao"]
				linha += " %3d/%-2d" % [cl.find("jogador") + 1, cl.size()]
		print(linha)
