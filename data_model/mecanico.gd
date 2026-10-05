class_name Mecanico
extends RefCounted
## Explica uma derrota com a própria simulação: refaz a corrida com cada peça e
## pneu que o jogador pode pagar e mostra o que melhora a posição. Não muda
## nada no jogo; só responde "o que ajuda?".
##
## Todas as opções são comparadas nas mesmas sementes (a diferença medida é do
## carro, não da sorte). As sementes ficam numa faixa própria, separada das
## corridas de verdade. O resultado é uma estimativa: a interface mostra a
## faixa típica ("1º–3º nos testes"), sem prometer o resultado.

const SEMENTE_BASE := 900000
## Corridas simuladas por opção. Escolhido com tools/validar_previsao.gd.
const AMOSTRAS := 8
## Diferença mínima de posição média para contar como melhora.
const GANHO_MINIMO := 0.25


## Retorna {"base": avaliação atual, "opcoes": [...]}. Cada avaliação tem
## {media, faixa: [melhor_tipica, pior_tipica]}; cada opção também {tipo,
## item, nome, preco, perde: [nomes de provas que o carro deixa de poder correr]}.
## Até `maximo` opções que melhoram, da maior melhora para a menor (empate: a
## mais barata). Peça já possuída custa 0 (só reinstalar).
static func analisar(carreira: Carreira, evento_id: String, uid: int, maximo: int = 3,
		amostras: int = AMOSTRAS) -> Dictionary:
	var jogador: Node = carreira.jogador
	var dados: Node = carreira.dados
	var carro: Carro = jogador.garagem.carro(uid)
	if carro == null:
		return {"base": {}, "opcoes": []}
	var base := avaliar(carreira, evento_id, uid, carro, amostras)
	var pode_antes := provas_possiveis(dados, carro)
	var boas := []
	for o in candidatas(dados, jogador, carro):
		if considerar(o, avaliar(carreira, evento_id, uid, o["carro"], amostras), base, pode_antes, dados):
			boas.append(o)
	return {"base": base, "opcoes": ordenar(boas, maximo)}


## Completa a opção com a avaliação e as provas que ela tira; true se ela
## melhora a posição média. Usado opção a opção pela tela (com progresso).
static func considerar(o: Dictionary, a: Dictionary, base: Dictionary, pode_antes: Array, dados: Node) -> bool:
	if a.is_empty() or a["media"] >= base["media"] - GANHO_MINIMO:
		return false
	var depois := provas_possiveis(dados, o["carro"])
	o["perde"] = pode_antes.filter(func(id): return not id in depois).map(func(id): return dados.evento(id)["nome"])
	o.merge(a)
	o.erase("carro")
	return true


## Da maior melhora para a menor (empate: a mais barata), até `maximo`.
static func ordenar(boas: Array, maximo: int) -> Array:
	boas.sort_custom(func(x, y): return x["media"] < y["media"] if absf(x["media"] - y["media"]) > 0.01 else x["preco"] < y["preco"])
	return boas.slice(0, maximo)


## Peças e pneus que o saldo paga, cada um já montado numa cópia do carro.
static func candidatas(dados: Node, jogador: Node, carro: Carro) -> Array:
	var r := []
	for p in dados.lista("pecas"):
		if carro.motivo_recusa(p) != "" or carro.pecas.get(p["categoria"], {}).get("id") == p["id"]:
			continue
		var preco: int = 0 if p["id"] in carro.pecas_possuidas else int(p["preco"])
		if not jogador.economia.pode_pagar(preco):
			continue
		var c := carro.copiar()
		c.instalar(p)
		r.append({"tipo": "peca", "item": p, "nome": p["nome"], "preco": preco, "carro": c})
	for pn in dados.lista("pneus"):
		if carro.pneus.any(func(x): return x["id"] == pn["id"]) or not jogador.economia.pode_pagar(int(pn["preco"])):
			continue
		var c := carro.copiar()
		c.adicionar_pneu(pn)
		r.append({"tipo": "pneu", "item": pn, "nome": pn["nome"], "preco": int(pn["preco"]), "carro": c})
	return r


## Posições do carro em `amostras` corridas simuladas: {media, faixa, posicoes};
## {} se ele não pode correr o evento. A faixa descarta o melhor e o pior
## resultado (a partir de 5 amostras), para não prometer o caso de sorte.
static func avaliar(carreira: Carreira, evento_id: String, uid: int, carro: Carro, amostras: int = AMOSTRAS,
		semente_base: int = SEMENTE_BASE) -> Dictionary:
	var posicoes := []
	for k in amostras:
		var r := carreira.preparar(evento_id, uid, semente_base + k, false, carro)
		if r.has("erro"):
			return {}
		posicoes.append(r["resultado"]["classificacao"].find("jogador") + 1)
	posicoes.sort()
	var corte := 1 if posicoes.size() >= 5 else 0
	return {
		"media": float(posicoes.reduce(func(a, b): return a + b)) / posicoes.size(),
		"faixa": [posicoes[corte], posicoes[posicoes.size() - 1 - corte]],
		"posicoes": posicoes,
	}


## Ids dos eventos cujas restrições de carro (potência, tração, categoria,
## fabricante, ano) o carro cumpre. Licença não entra: ela não muda com peças.
static func provas_possiveis(dados: Node, carro: Carro) -> Array:
	var r := []
	for ev in dados.lista("eventos"):
		var restr: Dictionary = ev["restricoes"].duplicate()
		restr.erase("licenca")
		if Elegibilidade.motivos(carro, restr, []).is_empty():
			r.append(ev["id"])
	return r


## Texto curto da faixa: "1º" ou "1º–3º".
static func texto_faixa(faixa: Array) -> String:
	return "%dº" % faixa[0] if faixa[0] == faixa[1] else "%dº–%dº" % [faixa[0], faixa[1]]
