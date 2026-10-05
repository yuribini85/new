class_name Mecanico
extends RefCounted
## Explica uma derrota com a própria simulação: refaz a corrida com cada peça e
## pneu que o jogador pode pagar e mostra o que melhora a posição média. Não
## muda nada no jogo; só responde "o que ajuda?".

const SEMENTES := [1, 2, 3]
## Diferença mínima de posição média para contar como melhora.
const GANHO_MINIMO := 0.25


## Retorna {"base": posição média atual, "opcoes": [{tipo, item, nome, preco,
## media}]} com até `maximo` opções que melhoram, da maior melhora para a menor
## (empate: a mais barata). Peça já possuída custa 0 (só reinstalar).
static func analisar(carreira: Carreira, evento_id: String, uid: int, maximo: int = 3) -> Dictionary:
	var jogador: Node = carreira.jogador
	var dados: Node = carreira.dados
	var carro: Carro = jogador.garagem.carro(uid)
	if carro == null:
		return {"base": 0.0, "opcoes": []}
	var base := _media(carreira, evento_id, uid, carro)
	var opcoes := []
	for p in dados.lista("pecas"):
		if carro.motivo_recusa(p) != "" or carro.pecas.get(p["categoria"], {}).get("id") == p["id"]:
			continue
		var preco: int = 0 if p["id"] in carro.pecas_possuidas else int(p["preco"])
		if not jogador.economia.pode_pagar(preco):
			continue
		var c := carro.copiar()
		c.instalar(p)
		opcoes.append({"tipo": "peca", "item": p, "nome": p["nome"], "preco": preco, "carro": c})
	for pn in dados.lista("pneus"):
		if carro.pneus.any(func(x): return x["id"] == pn["id"]) or not jogador.economia.pode_pagar(int(pn["preco"])):
			continue
		var c := carro.copiar()
		c.adicionar_pneu(pn)
		opcoes.append({"tipo": "pneu", "item": pn, "nome": pn["nome"], "preco": int(pn["preco"]), "carro": c})
	var boas := []
	for o in opcoes:
		var m := _media(carreira, evento_id, uid, o["carro"])
		if m >= 0.0 and m < base - GANHO_MINIMO:
			o["media"] = m
			o.erase("carro")
			boas.append(o)
	boas.sort_custom(func(a, b): return a["media"] < b["media"] if absf(a["media"] - b["media"]) > 0.01 else a["preco"] < b["preco"])
	return {"base": base, "opcoes": boas.slice(0, maximo)}


## Posição média nas SEMENTES; -1 se o carro não pode correr o evento.
static func _media(carreira: Carreira, evento_id: String, uid: int, carro: Carro) -> float:
	var soma := 0.0
	for s in SEMENTES:
		var r := carreira.preparar(evento_id, uid, s, false, carro)
		if r.has("erro"):
			return -1.0
		soma += r["resultado"]["classificacao"].find("jogador") + 1
	return soma / SEMENTES.size()
