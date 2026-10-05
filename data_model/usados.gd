class_name Usados
extends RefCounted
## Estoque de usados como no GT2: cada carro de data/carros.json pode ter
## `usados: [[dia_inicio, dia_fim, preco], ...]`, as janelas em que aparece na
## concessionária de usados e o preço de cada uma (no GT2, períodos de 10 dias).
## O dia é o número de corridas disputadas (docs/plano_mvp.md, decisão 5).


## Ofertas do dia: [{carro_id, preco, chave, fim}], da mais barata para a mais
## cara. `vendidos` guarda chaves já compradas: somem até a próxima janela.
static func estoque(carros: Array, dia: int, vendidos: Dictionary) -> Array:
	var ofertas := []
	for c in carros:
		for janela in c.get("usados", []):
			if dia < int(janela[0]) or dia > int(janela[1]):
				continue
			var chave := "%d:%s" % [int(janela[0]), c["id"]]
			if not vendidos.has(chave):
				ofertas.append({"carro_id": c["id"], "preco": int(janela[2]), "chave": chave, "fim": int(janela[1])})
	ofertas.sort_custom(func(a, b): return a["preco"] < b["preco"])
	return ofertas
