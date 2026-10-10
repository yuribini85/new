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


## Próximas ofertas, das que começam mais cedo para as mais tarde: janelas
## que ainda não abriram em `dia` e abrem até `dia + horizonte`.
## [{carro_id, preco, inicio, fim}]. O estoque é fixo por dia de jogo, então a
## agenda é exata (não é previsão).
static func agenda(carros: Array, dia: int, horizonte: int) -> Array:
	var r := []
	for c in carros:
		for janela in c.get("usados", []):
			var ini := int(janela[0])
			if ini > dia and ini <= dia + horizonte:
				r.append({"carro_id": c["id"], "preco": int(janela[2]), "inicio": ini, "fim": int(janela[1])})
	r.sort_custom(func(a, b): return a["inicio"] < b["inicio"] if a["inicio"] != b["inicio"] else a["preco"] < b["preco"])
	return r


## Próxima janela de um modelo a partir de `dia` (a aberta hoje conta), ou {}.
static func proxima(carro: Dictionary, dia: int, vendidos: Dictionary) -> Dictionary:
	var melhor := {}
	for janela in carro.get("usados", []):
		var ini := int(janela[0])
		var fim := int(janela[1])
		if fim < dia or vendidos.has("%d:%s" % [ini, carro["id"]]):
			continue
		if melhor.is_empty() or ini < melhor["inicio"]:
			melhor = {"carro_id": carro["id"], "preco": int(janela[2]), "inicio": ini, "fim": fim}
	return melhor
