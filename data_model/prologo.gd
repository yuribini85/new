class_name Prologo
extends RefCounted
## Prólogo da história (decisão 32; data/historia.json): o jogo novo começa com
## Adrian (licenças Club e Sport, o carro dele e o dinheiro da primeira peça). Depois
## do primeiro campeonato (flag de `ultima_corrida_apos`), a próxima largada é a
## última corrida dele: rádio em `radio_fracao` da corrida e acidente em
## `acidente_fracao` — a corrida é interrompida sem resultado e a garagem fica
## vazia. No salto temporal, Elena volta sem licença, sem carro e com a
## poupança (`elena.saldo`: "saldo_inicial" = o saldo inicial do GT2).
## As frações são momentos da apresentação, não balanceamento.


## Começa um jogo novo como Adrian. "" ou o motivo de não poder (dados faltando).
## O carro dele (`carro`, na cor `cor`) já vem com o pneu `pneu`; o freio é o de
## fábrica, e a primeira demanda é comprar `peca_demanda`.
static func iniciar(dados: Node, jogador: Node) -> String:
	var cfg: Dictionary = dados.historia().get("adrian", {})
	if cfg.is_empty() or not dados.existe("carros", cfg.get("carro", "")):
		return "historia.json sem o carro do Adrian"
	jogador.novo_jogo(dados.economia(), dados.pneu)
	jogador.personagem = "adrian"
	jogador.licencas = Array(cfg.get("licencas", [])).duplicate()
	var carro := Carro.new(dados.carro(cfg["carro"]))
	carro.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
	if dados.existe("pneus", String(cfg.get("pneu", ""))):
		carro.adicionar_pneu(dados.pneu(cfg["pneu"]))
	if String(cfg.get("cor", "")) != "":
		carro.cor = "#" + Cores.cor(cfg["cor"]).to_html(false)
	jogador.carro_ativo = jogador.garagem.adicionar(carro)
	jogador.economia.saldo = saldo_inicial(dados, cfg["carro"], String(cfg.get("peca_demanda", "")))
	return ""


## Giros do começo (critério do usuário): a peça da demanda mais a peça mais
## barata do carro, menos 1 — sobra dinheiro, mas não para uma segunda compra.
static func saldo_inicial(dados: Node, carro_id: String, peca_id: String) -> int:
	if not dados.existe("pecas", peca_id):
		return 0
	var mais_barata := -1
	for p in dados.lista("pecas"):
		var permitidos: Array = p.get("carros_permitidos", [])
		if p["id"] == peca_id or (not permitidos.is_empty() and not carro_id in permitidos):
			continue
		if mais_barata < 0 or int(p["preco"]) < mais_barata:
			mais_barata = int(p["preco"])
	return int(dados.peca(peca_id)["preco"]) + maxi(mais_barata - 1, 0)


## O carro do Adrian não pode ser vendido no prólogo (só sai no acidente).
static func carro_travado(dados: Node, jogador: Node, carro: Carro) -> bool:
	return jogador.personagem == "adrian" and carro != null \
			and carro.id == String(dados.historia().get("adrian", {}).get("carro", ""))


## A próxima largada do Adrian é a última corrida.
static func deve_ultima_corrida(dados: Node, jogador: Node) -> bool:
	return jogador.personagem == "adrian" and jogador.flags.has(String(dados.historia().get("ultima_corrida_apos", ""))) \
			and not jogador.flags.has("ADRIAN_DEAD")


## A última corrida está em andamento.
static func ultima_corrida_ativa(jogador: Node) -> bool:
	return jogador.personagem == "adrian" and jogador.flags.has("LAST_RACE_STARTED") \
			and not jogador.flags.has("ADRIAN_DEAD") and not jogador.fila.is_empty()


## Acidente: a corrida para sem resultado nem prêmio e o carro sai para sempre.
static func acidente(jogador: Node) -> void:
	jogador.fila = {}
	for c in jogador.garagem.lista():
		jogador.garagem.remover(c.uid)
	jogador.carro_ativo = -1
	jogador.ultima_corrida = {}
	jogador.flags["ADRIAN_CAR_DESTROYED"] = true


## Salto temporal: Elena, sem licença, sem carro, com a poupança. A carreira
## dela começa do zero (vitórias, histórico e campeonatos eram do Adrian); dias,
## flags e cenas vistas continuam.
static func salto_temporal(dados: Node, jogador: Node) -> void:
	jogador.personagem = "elena"
	jogador.licencas = []
	jogador.graus_licenca = {}
	jogador.treinos = {}
	jogador.montagens = {}
	jogador.vitorias = {}
	jogador.historico = {}
	jogador.campeonatos = {}
	jogador.titulos = {}
	jogador.fila = {}
	var saldo = dados.historia().get("elena", {}).get("saldo", "saldo_inicial")
	jogador.economia.saldo = int(dados.economia()["saldo_inicial"]) if saldo is String else int(saldo)


## Second Chance Motors: entre os usados do dia que o saldo paga, um de cada
## perfil (barato, leve, potente, equilibrado, caro), até `second_chance.carros`.
static func second_chance(dados: Node, jogador: Node, ofertas: Array) -> Array:
	var cabe := ofertas.filter(func(o): return jogador.economia.pode_pagar(int(o["preco"])))
	if cabe.is_empty():
		return []
	var por := func(chave: Callable) -> Array:
		var l := cabe.duplicate()
		l.sort_custom(func(a, b): return chave.call(a) < chave.call(b))
		return l
	var preco := func(o): return int(o["preco"])
	var peso := func(o): return int(dados.carro(o["carro_id"])["peso"])
	var potencia := func(o): return -int(dados.carro(o["carro_id"])["potencia"])
	var precos: Array = por.call(preco)
	var escolha := [precos[0], por.call(peso)[0], por.call(potencia)[0], precos[precos.size() / 2], precos[-1]]
	var r := []
	for o in escolha:
		if not r.any(func(x): return x["chave"] == o["chave"]):
			r.append(o)
	return r.slice(0, int(dados.historia().get("second_chance", {}).get("carros", 5)))
