extends "res://tests/base_teste.gd"
## Percurso inicial com os dados REAIS de data/ (não fixtures): confere que o
## balanceamento importado do GT2 sustenta a experiência de 20–30 minutos.
## Jogador automático: compra o usado com melhor previsão, corre as provas sem
## licença em ordem de prêmio, segue o "O que ajuda?" após cada derrota e tenta
## a licença B. Exige a licença B em até 30 min de corrida e ao menos um ciclo
## derrota → compra → vitória NA MESMA PROVA (a compra resolve o que a motivou).
## O tempo conta só corrida: leitura, compras e navegação ficam para o playtest.

const JogadorScript := preload("res://autoload/jogador.gd")
const LIMITE_S := 30.0 * 60.0


func test_percurso_inicial_ate_a_licenca_b() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	j.carreira = Carreira.new(d, j)
	var log := []
	var tempo := 0.0
	var semente := 0

	# 1. Primeiro carro: o usado de melhor previsão que o saldo paga.
	var sem_licenca: Array = d.lista("eventos").filter(func(e): return not e["restricoes"].has("licenca") and not e["premios"].is_empty())
	sem_licenca.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0] if a["premios"][0] != b["premios"][0] else a["nome"] < b["nome"])
	var melhor := {}
	var melhor_media := 99.0
	for o in Usados.estoque(d.lista("carros"), 0, j.usados_vendidos):
		if not j.economia.pode_pagar(o["preco"]):
			continue
		var c := Carro.new(d.carro(o["carro_id"]))
		c.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
		var a := Mecanico.avaliar(j.carreira, sem_licenca[0]["id"], -1, c)
		var m: float = a.get("media", -1.0)
		if m >= 0.0 and m < melhor_media:
			melhor_media = m
			melhor = o
	verificar(not melhor.is_empty(), "algum usado inicial cabe no saldo")
	if melhor.is_empty():
		j.free()
		d.free()
		return
	var uid: int = j.concessionaria.comprar_usado(melhor, d.carro(melhor["carro_id"]), j.usados_vendidos)
	log.append("comprou %s por %d (previsão %.1fº)" % [melhor["carro_id"], melhor["preco"], melhor_media])

	# 2. Provas sem licença em ordem; derrota -> mecânico -> compra.
	var ciclo_completo := false
	for ev in sem_licenca:
		var comprou_aqui := false
		if tempo > LIMITE_S * 0.7:
			break
		for tentativa in 6:
			semente += 1
			var r: Dictionary = j.carreira.disputar(ev["id"], uid, semente)
			if r.has("erro"):
				log.append("%s: não pode correr (%s)" % [ev["nome"], r["erro"]])
				break
			tempo += float(r["resultado"]["duracao"])
			log.append("%s: %dº, +%d (saldo %d, %.0f s)" % [ev["nome"], r["posicao"], r["premio"], j.economia.saldo, tempo])
			if r["posicao"] == 1:
				if comprou_aqui:
					ciclo_completo = true
				break
			var a: Dictionary = Mecanico.analisar(j.carreira, ev["id"], uid, 1)
			if not a["opcoes"].is_empty():
				var o: Dictionary = a["opcoes"][0]
				if o["tipo"] == "peca":
					j.concessionaria.comprar_peca(j.garagem.carro(uid), o["item"])
				else:
					j.concessionaria.comprar_pneu(j.garagem.carro(uid), o["item"])
				comprou_aqui = true
				log.append("  comprou %s por %d (%s -> %s nos testes)" % [o["nome"], o["preco"],
						Mecanico.texto_faixa(a["base"]["faixa"]), Mecanico.texto_faixa(o["faixa"])])

	# 3. Licença B.
	var licencas := Licencas.new(d, j)
	for lic in d.lista("licencas"):
		if lic["id"] != "B":
			continue
		for t in lic["testes"]:
			for tentativa in 3:
				semente += 1
				var r := licencas.fazer_teste("B", t["id"], uid, semente)
				if r.has("erro"):
					log.append("teste %s: %s" % [t["id"], r["erro"]])
					break
				tempo += float(r["tempo"])
				log.append("teste %s: %.2f s %s" % [t["id"], r["tempo"], r["grau"] if r["grau"] != "" else "reprovado"])
				if r["grau"] != "":
					break

	print("\n  percurso (%.1f min):\n    " % (tempo / 60.0) + "\n    ".join(log))
	verificar("B" in j.licencas, "licença B conquistada")
	verificar(tempo <= LIMITE_S, "dentro de 30 min de corrida: %.1f min" % (tempo / 60.0))
	verificar(ciclo_completo, "houve derrota, compra e vitória na mesma prova")
	j.free()
	d.free()


func test_dados_reais_tem_peca_que_tira_carro_de_prova() -> void:
	# Garante que o aviso de elegibilidade tem caso real para mostrar: algum
	# carro que cabe numa prova de fábrica e sai dela com uma peça própria.
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var achou := ""
	for c in d.lista("carros"):
		var carro := Carro.new(c)
		carro.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
		var antes := Mecanico.provas_possiveis(d, carro)
		for p in d.lista("pecas"):
			if carro.motivo_recusa(p) != "":
				continue
			var com := carro.copiar()
			com.instalar(p)
			var depois := Mecanico.provas_possiveis(d, com)
			var perdidas := antes.filter(func(id): return not id in depois)
			if not perdidas.is_empty():
				achou = "%s (%d cv) + %s sai de %s" % [c["nome"], c["potencia"], p["nome"], d.evento(perdidas[0])["nome"]]
				break
		if achou != "":
			break
	print("\n  caso real: " + achou)
	verificar(achou != "", "algum carro real perde uma prova por causa de uma peça")
	d.free()
