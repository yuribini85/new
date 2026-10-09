extends "res://tests/base_teste.gd"
## Percurso inicial com os dados REAIS de data/ (não fixtures): confere que o
## balanceamento importado do GT2 sustenta o começo. Jogador automático
## (tools/agente.gd, perfil "sugestoes") com cada usado inicial: exige uma
## vitória e a licença B (contratos) em até 30 min de corrida, e ao menos um
## ciclo derrota → compra → vitória NA MESMA PROVA (a compra resolve o que a
## motivou). O tempo conta só corrida: leitura e navegação ficam para o playtest.

const JogadorScript := preload("res://autoload/jogador.gd")
const LIMITE_S := 30.0 * 60.0


func test_percurso_inicial_ate_a_licenca_b() -> void:
	# Agente "sugestoes" (tools/agente.gd) com cada usado inicial que o saldo
	# paga E que tem boa chance na primeira corrida aberta (posição média de
	# fábrica até 1,5 na prova aberta sem licença de menor prêmio). O Mercado
	# não recomenda nada, como no GT2: este filtro é só a conferência de que
	# existem bons primeiros carros. Com o GT2 inteiro há dezenas de usados
	# iniciais, e alguns não sustentam o começo, como no GT2.
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var saldo := int(d.economia()["saldo_inicial"])
	var ofertas: Array = Usados.estoque(d.lista("carros"), 0, {}).filter(func(o): return int(o["preco"]) <= saldo)
	verificar(not ofertas.is_empty(), "algum usado inicial cabe no saldo")
	var j: Node = JogadorScript.new()
	j.novo_jogo(d.economia(), d.pneu)
	var carreira := Carreira.new(d, j)
	var faceis: Array = d.lista("eventos").filter(Elegibilidade.aberta_sem_licenca)
	faceis.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0])
	ofertas = ofertas.filter(func(o):
		var c := Carro.new(d.carro(o["carro_id"]))
		c.adicionar_pneu(d.pneu(d.economia()["pneu_de_fabrica"]))
		var a := Mecanico.avaliar(carreira, faceis[0]["id"], -1, c)
		return not a.is_empty() and float(a["media"]) <= 1.5)
	j.free()
	print("\n  bons iniciais: %d" % ofertas.size())
	verificar(not ofertas.is_empty(), "há usado inicial com boa chance na primeira corrida")
	var ciclo := false
	for o in ofertas:
		var ag = preload("res://tools/agente.gd").new(d, "sugestoes", hash(o["carro_id"]))
		var r: Dictionary = ag.jogar(o, LIMITE_S)
		ag.liberar()
		var m: Dictionary = r["marcos"]
		print("\n  %s (%.1f min): %s" % [o["carro_id"], r["tempo"] / 60.0, "; ".join(r["log"].slice(0, 8))])
		verificar(m.has("primeira_vitoria"), "%s vence uma prova" % o["carro_id"])
		verificar(m.has("licenca_b") and float(m["licenca_b"]) <= LIMITE_S,
				"%s tira a B em até 30 min de corrida" % o["carro_id"])
		ciclo = ciclo or m.has("ciclo")
	verificar(ciclo, "em algum percurso houve derrota, compra e vitória na mesma prova")
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


func test_agente_mede_por_fase_com_os_contratos() -> void:
	var d: Node = DadosScript.new()
	d.carregar("res://data/")
	var saldo := int(d.economia()["saldo_inicial"])
	var oferta: Dictionary = Usados.estoque(d.lista("carros"), 0, {}).filter(func(o): return int(o["preco"]) <= saldo)[0]
	var ag = preload("res://tools/agente.gd").new(d, "sugestoes", 1)
	# Mesmo horizonte do percurso até a B: com as voltas ×2,5 (decisão 41) a
	# primeira vitória já passa de 12 min, e a avaliação da Club vem depois dela.
	var r: Dictionary = ag.jogar(oferta, LIMITE_S)
	ag.liberar()
	verificar(r["marcos"].has("primeira_vitoria"), "venceu uma prova")
	verificar("CLUB" in r["licencas"], "licença Club pelos contratos, depois da primeira vitória")
	verificar(r["fases"].has("sem licença") and r["fases"].has("CLUB"), "contabilidade por fase")
	var bruto := 0
	var gastos := 0
	for f in r["fases"]:
		bruto += int(r["fases"][f]["bruto"])
		gastos += int(r["fases"][f]["gastos"])
	igual(r["saldo"], saldo + bruto - gastos, "saldo = inicial + renda bruta − gastos")
	d.free()
