extends SceneTree
## Valida as previsões do Mecanico com sementes independentes.
## Casos: carros de fábrica em provas onde ficam atrás (média >= 2). Para cada
## quantidade de amostras, prevê a melhor opção e confere com VALIDACAO
## corridas em outra faixa de sementes:
##   erro      |média prevista - média validada| da opção recomendada
##   cobertura fração das corridas validadas dentro da faixa mostrada
##   acerto    fração dos casos em que a opção recomendada melhora mesmo
## Uso: godot --headless --script res://tools/validar_previsao.gd [-- --casos=40]

const VALIDACAO := 40
const SEMENTE_VALIDACAO := 5000000

var _feito := false


func _process(_d: float) -> bool:
	if not _feito:
		_feito = true
		_rodar()
		quit()
	return false


func _rodar() -> void:
	var dados: Node = root.get_node("Dados")
	var jog: Node = root.get_node("Jogador")
	var max_casos := 40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--casos="):
			max_casos = int(arg.trim_prefix("--casos="))
	jog.novo_jogo(dados.economia(), dados.pneu)
	jog.carreira = Carreira.new(dados, jog)
	jog.licencas = ["CLUB", "SPORT"]
	jog.economia.saldo = 20000  # orçamento de começo de carreira
	# Casos determinísticos: carros x eventos sem licença ou B, intercalados.
	var casos := []
	for ev in dados.lista("eventos"):
		if ev["restricoes"].get("licenca", "") == "SPORT":
			continue
		for c in dados.lista("carros"):
			casos.append([c["id"], ev["id"]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(casos.size() - 1, 0, -1):
		var k := rng.randi_range(0, i)
		var t = casos[i]
		casos[i] = casos[k]
		casos[k] = t
	var escolhidos := []
	for caso in casos:
		if escolhidos.size() >= max_casos:
			break
		var carro := _carro(dados, caso[0])
		jog.garagem.carros.clear()
		var uid: int = jog.garagem.adicionar(carro)
		var a := Mecanico.avaliar(jog.carreira, caso[1], uid, carro, 8)
		if not a.is_empty() and a["media"] >= 2.0:
			escolhidos.append(caso)
	print("casos: %d (perdendo de fábrica)" % escolhidos.size())
	for n in [5, 8, 12]:
		var erros := []
		var dentro := 0
		var total := 0
		var acertos := 0
		var com_opcao := 0
		var t0 := Time.get_ticks_msec()
		for caso in escolhidos:
			jog.garagem.carros.clear()
			var carro := _carro(dados, caso[0])
			var uid: int = jog.garagem.adicionar(carro)
			var r := Mecanico.analisar(jog.carreira, caso[1], uid, 1, n)
			if r["opcoes"].is_empty():
				continue
			com_opcao += 1
			var o: Dictionary = r["opcoes"][0]
			var com := carro.copiar()
			if o["tipo"] == "peca":
				com.instalar(o["item"])
			else:
				com.adicionar_pneu(o["item"])
			var val_opcao := Mecanico.avaliar(jog.carreira, caso[1], uid, com, VALIDACAO, SEMENTE_VALIDACAO)
			var val_base := Mecanico.avaliar(jog.carreira, caso[1], uid, carro, VALIDACAO, SEMENTE_VALIDACAO)
			erros.append(absf(o["media"] - val_opcao["media"]))
			for p in val_opcao["posicoes"]:
				total += 1
				if p >= o["faixa"][0] and p <= o["faixa"][1]:
					dentro += 1
			if val_opcao["media"] < val_base["media"] - 0.01:
				acertos += 1
		erros.sort()
		print("amostras %2d: casos com opção %d · erro médio %.2f (mediana %.2f, pior %.2f) · cobertura %.0f%% · acerto %.0f%% · %.1f s" % [
			n, com_opcao, erros.reduce(func(a, b): return a + b, 0.0) / maxi(erros.size(), 1),
			erros[erros.size() / 2] if not erros.is_empty() else 0.0, erros.back() if not erros.is_empty() else 0.0,
			100.0 * dentro / maxi(total, 1), 100.0 * acertos / maxi(com_opcao, 1), (Time.get_ticks_msec() - t0) / 1000.0])


func _carro(dados: Node, id: String) -> Carro:
	var c := Carro.new(dados.carro(id))
	c.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	return c
