class_name Usados
extends RefCounted
## Estoque de usados (docs/plano_mvp.md, decisão 5). Cada carro com
## `usado_dias: [início, fim]` aparece enquanto o dia do jogador estiver na
## faixa. O estoque muda a cada período de `usado_periodo_dias`; dentro do
## período, a quilometragem é fixa (sorteada por carro e período).
## Quilometragem só afeta o preço — no GT2 o usado não perde desempenho.
## Parâmetros em data/economia.json (usado_*).

static func periodo(dia: int, regras: Dictionary) -> int:
	return floori(float(dia) / float(regras["usado_periodo_dias"]))


## Ofertas do dia: [{carro_id, km, preco, chave}]. `vendidos` são chaves já
## compradas neste período.
static func estoque(carros: Array, dia: int, regras: Dictionary, vendidos: Dictionary) -> Array:
	var p := periodo(dia, regras)
	var ofertas := []
	for c in carros:
		var faixa = c.get("usado_dias")
		if faixa == null or dia < int(faixa[0]) or dia > int(faixa[1]):
			continue
		var chave := "%d:%s" % [p, c["id"]]
		if vendidos.has(chave):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(chave)
		var km := rng.randi_range(int(regras["usado_km_min"]), int(regras["usado_km_max"]))
		var fracao := maxf(1.0 - km * float(regras["usado_desconto_por_km"]), float(regras["usado_fracao_minima"]))
		ofertas.append({"carro_id": c["id"], "km": km, "preco": int(floor(float(c["preco"]) * fracao)), "chave": chave})
	ofertas.sort_custom(func(a, b): return a["preco"] < b["preco"])
	return ofertas
