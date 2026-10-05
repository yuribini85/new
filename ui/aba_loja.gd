extends Aba

## Perspectiva para quem está escolhendo o primeiro carro: faixa de posição de
## cada usado, de fábrica, em corridas simuladas da primeira prova sem licença
## (a de menor prêmio). Estimativa, não promessa. Uma vez por dia de jogo.
var _previsao := {}  # {"dia", "evento", "avaliacoes": {carro_id: Mecanico.avaliar()}}


func _init(d: Node, j: Node) -> void:
	super(d, j, "Loja")


func construir() -> void:
	titulo("Usados — dia %d" % jogador.dias)
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	if ofertas.is_empty():
		texto("Nenhum usado hoje.")
	var prev := _prever(ofertas)
	if not prev.is_empty():
		texto("De fábrica em %s, nos testes:" % prev["evento"], Color(0.7, 0.8, 1.0))
	for o in ofertas:
		var c: Dictionary = dados.carro(o["carro_id"])
		var desc := "%s · %s · %d cv" % [c["nome"], c["tracao"], c["potencia"]]
		var a: Dictionary = prev.get("avaliacoes", {}).get(o["carro_id"], {})
		if not a.is_empty():
			desc += " · %s%s" % ["★ boa perspectiva · " if a["media"] <= 1.5 else "", Mecanico.texto_faixa(a["faixa"])]
		linha(desc, [
			[dinheiro(o["preco"]), func(): _escolher(jogador.concessionaria.comprar_usado(o, c, jogador.usados_vendidos)),
				jogador.economia.pode_pagar(o["preco"])],
		], icone_carro(c))
	separador()
	titulo("Novos")
	for c in dados.lista("carros"):
		if not c.get("novo", true):
			continue  # como no GT2: modelos antigos só no usado
		var preco := int(c["preco"])
		var fab: String = dados.item("fabricantes", c["fabricante"]).get("nome", c["fabricante"])
		linha("%s · %s · %s · %d cv · %d" % [c["nome"], fab, c["tracao"], c["potencia"], c["ano"]], [
			[dinheiro(preco), func(): _escolher(jogador.concessionaria.comprar_carro(c)), jogador.economia.pode_pagar(preco)],
		], icone_carro(c))


func _prever(ofertas: Array) -> Dictionary:
	if jogador.carreira == null:
		return {}
	if _previsao.get("dia", -1) == jogador.dias:
		return _previsao
	var sem_licenca: Array = dados.lista("eventos").filter(func(e): return not e["restricoes"].has("licenca") and not e["premios"].is_empty())
	if sem_licenca.is_empty():
		return {}
	sem_licenca.sort_custom(func(a, b): return a["premios"][0] < b["premios"][0])
	var ev: Dictionary = sem_licenca[0]
	var avaliacoes := {}
	for o in ofertas:
		var c := Carro.new(dados.carro(o["carro_id"]))
		c.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
		avaliacoes[o["carro_id"]] = Mecanico.avaliar(jogador.carreira, ev["id"], -1, c)
	_previsao = {"dia": jogador.dias, "evento": ev["nome"], "avaliacoes": avaliacoes}
	return _previsao


func _escolher(uid: int) -> void:
	if uid > 0 and jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
