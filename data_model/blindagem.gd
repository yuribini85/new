class_name Blindagem
extends RefCounted
## Blindagem do carro (pedido do usuário): três níveis comprados na Oficina,
## ao lado da velocidade máxima. É peso a mais na carroceria: na arena a
## resistência de cada região é ½·m·v_ref² (Arena), então o carro mais pesado
## aguenta mais pancada; na corrida, o mesmo peso tira aceleração, freio e curva.
##
## Números (CLAUDE.md: nada inventado): espelho da redução de peso do GT2 do
## próprio carro (data/pecas.json, categoria em data/arena.json → blindagem
## → referencia). O nível k pesa o inverso do que o estágio k da redução tira
## (×0,95 vira ×1/0,95) e custa o mesmo que ele. Carro sem redução de peso no
## disco: o fator mais comum de cada estágio na frota e o preço pela razão
## mediana estágio/preço do carro. Viram peças comuns (categoria "blindagem"),
## geradas ao carregar os dados: compra, uso, save e fila já sabem lidar.

const CATEGORIA := "blindagem"


static func id_peca(carro_id: String, nivel: int) -> String:
	return "%s_%s_%d" % [carro_id, CATEGORIA, nivel]


## As peças de blindagem de toda a frota, a partir da redução de peso.
## `cfg` = data/arena.json → blindagem; vazio = sem blindagem.
static func gerar(pecas: Array, carros: Array, cfg: Dictionary) -> Array:
	if cfg.is_empty():
		return []
	var ref := String(cfg.get("referencia", ""))
	var niveis := int(cfg.get("niveis", 0))
	var nomes: Array = cfg.get("nomes", [])
	# carro -> {estágio: [fator, preço]}
	var por_carro := {}
	for p in pecas:
		if p["categoria"] != ref:
			continue
		var k := int(String(p["id"]).get_slice("_", String(p["id"]).get_slice_count("_") - 1))
		var fator := 0.0
		for e in p["efeitos"]:
			if e["atributo"] == "peso" and e["op"] == "mult":
				fator = float(e["valor"])
		if fator <= 0.0:
			continue
		for c in p.get("carros_permitidos", []):
			if not por_carro.has(c):
				por_carro[c] = {}
			por_carro[c][k] = [fator, int(p["preco"])]
	if por_carro.is_empty():
		return []
	var preco_carro := {}
	for c in carros:
		preco_carro[c["id"]] = c.get("preco")
	# Para quem não tem: fator mais comum e razão mediana de preço por estágio.
	var comum := {}
	var razao := {}
	for k in range(1, niveis + 1):
		var conta := {}
		var razoes := []
		for c in por_carro:
			if not por_carro[c].has(k):
				continue
			var f: float = por_carro[c][k][0]
			conta[f] = int(conta.get(f, 0)) + 1
			if preco_carro.get(c) != null and float(preco_carro[c]) > 0.0:
				razoes.append(float(por_carro[c][k][1]) / float(preco_carro[c]))
		var melhor := 0.0
		for f in conta:
			if melhor == 0.0 or conta[f] > conta[melhor]:
				melhor = f
		comum[k] = melhor
		razoes.sort()
		razao[k] = razoes[razoes.size() / 2] if not razoes.is_empty() else 0.0
	var r := []
	for c in carros:
		if c.get("preco") == null:
			continue
		for k in range(1, niveis + 1):
			var par: Array = por_carro.get(c["id"], {}).get(k, [comum[k], roundi(float(c["preco"]) * razao[k])])
			if float(par[0]) <= 0.0:
				continue
			r.append({"id": id_peca(c["id"], k), "nome": String(nomes[k - 1]) if k - 1 < nomes.size() else "Blindagem %d" % k,
					"categoria": CATEGORIA, "nivel": k, "preco": int(par[1]), "carros_permitidos": [c["id"]],
					"efeitos": [{"atributo": "peso", "op": "mult", "valor": 1.0 / float(par[0])}]})
	return r


## Nível em uso no carro (0 = sem blindagem).
static func nivel(carro: Carro) -> int:
	return int(carro.pecas.get(CATEGORIA, {}).get("nivel", 0))


## Os níveis à venda para o carro, do 1 ao 3.
static func itens(dados: Node, carro: Carro) -> Array:
	var l: Array = dados.lista("pecas").filter(func(p): return p["categoria"] == CATEGORIA and carro.motivo_recusa(p).is_empty())
	l.sort_custom(func(a, b): return int(a["nivel"]) < int(b["nivel"]))
	return l


## Quanto a resistência na arena cresce com o nível (a mesma razão do peso).
static func ganho_arena(peca: Dictionary) -> float:
	for e in peca.get("efeitos", []):
		if e["atributo"] == "peso" and e["op"] == "mult":
			return float(e["valor"])
	return 1.0
