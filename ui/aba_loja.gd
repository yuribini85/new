extends Aba


func _init(d: Node, j: Node) -> void:
	super(d, j, "Loja")


func construir() -> void:
	titulo("Novos")
	for c in dados.lista("carros"):
		var preco := int(c["preco"])
		var fab: String = dados.item("fabricantes", c["fabricante"]).get("nome", c["fabricante"])
		linha("%s · %s · %s · %d cv · %d" % [c["nome"], fab, c["tracao"], c["potencia"], c["ano"]], [
			[dinheiro(preco), func(): _escolher(jogador.concessionaria.comprar_carro(c)), jogador.economia.pode_pagar(preco)],
		])
	separador()
	titulo("Usados — dia %d" % jogador.dias)
	var ofertas := Usados.estoque(dados.lista("carros"), jogador.dias, jogador.usados_vendidos)
	if ofertas.is_empty():
		texto("Nenhum usado hoje.")
	for o in ofertas:
		var c: Dictionary = dados.carro(o["carro_id"])
		linha("%s · %s · %d cv" % [c["nome"], c["tracao"], c["potencia"]], [
			[dinheiro(o["preco"]), func(): _escolher(jogador.concessionaria.comprar_usado(o, c, jogador.usados_vendidos)),
				jogador.economia.pode_pagar(o["preco"])],
		])


func _escolher(uid: int) -> void:
	if uid > 0 and jogador.carro_ativo < 0:
		jogador.carro_ativo = uid
