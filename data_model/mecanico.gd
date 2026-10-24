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
## Provas longas (resistência) usam menos corridas: o total de voltas simuladas
## fica perto de AMOSTRAS × VOLTAS_REFERENCIA, com no mínimo AMOSTRAS_MIN. Medido
## nas 7 resistências (30 a 99 voltas): a posição quase não varia entre sementes
## (12 sementes, 21 casos: 15 sempre iguais, os outros com uma posição diferente
## em até 3 sementes), e 99 voltas custam ~1,2 s por corrida.
const VOLTAS_REFERENCIA := 10
const AMOSTRAS_MIN := 2


## Corridas por opção para a prova: AMOSTRAS nas curtas, menos nas longas.
static func amostras_para(ev: Dictionary) -> int:
	var voltas := maxi(int(ev.get("voltas", 1)), 1)
	return clampi(ceili(float(AMOSTRAS * VOLTAS_REFERENCIA) / voltas), AMOSTRAS_MIN, AMOSTRAS)
## Diferença mínima de posição média para contar como melhora.
const GANHO_MINIMO := 0.25
## Triagem: cada opção corre primeiro TRIAGEM corridas (as primeiras sementes);
## só a que melhora nelas ganha a avaliação completa. As sementes são as mesmas
## para todas, então a diferença vem do carro; corta a análise pela metade (19
## opções numa prova da Club: 6 a 17 s sem triagem num desktop).
const TRIAGEM := 2


## Retorna {"base": avaliação atual, "opcoes": [...]}. Cada avaliação tem
## {media, faixa: [melhor_tipica, pior_tipica]}; cada opção também {tipo,
## item, nome, preco, perde: [nomes de provas que o carro deixa de poder correr]}.
## Até `maximo` opções que melhoram, na ordem de `ordenar` (melhora por giro).
## Peça já possuída custa 0 (só reinstalar).
static func analisar(carreira: Carreira, evento_id: String, uid: int, maximo: int = 3,
		amostras: int = AMOSTRAS) -> Dictionary:
	var jogador: Node = carreira.jogador
	var dados: Node = carreira.dados
	var carro: Carro = jogador.garagem.carro(uid)
	if carro == null:
		return {"base": {}, "opcoes": []}
	var base := avaliar(carreira, evento_id, uid, carro, amostras)
	var base_t := avaliar(carreira, evento_id, uid, carro, mini(TRIAGEM, amostras))
	var pode_antes := provas_possiveis(dados, carro)
	var boas := []
	for o in candidatas(dados, jogador, carro):
		if not passa_triagem(avaliar(carreira, evento_id, uid, o["carro"], mini(TRIAGEM, amostras)), base_t):
			continue
		if considerar(o, avaliar(carreira, evento_id, uid, o["carro"], amostras), base, pode_antes, dados):
			boas.append(o)
	return {"base": base, "opcoes": ordenar(boas, base, maximo)}


## A opção melhora nas corridas da triagem (qualquer melhora: a avaliação
## completa decide se passa de GANHO_MINIMO).
static func passa_triagem(a: Dictionary, base_t: Dictionary) -> bool:
	return not a.is_empty() and a["media"] < base_t["media"]


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


## Da que mais melhora por giro gasto para a que menos, até `maximo` (análise
## do jogo, 2026-10-19: ordenar só pela melhora punha na frente pneus que
## custavam mais que o carro e deixava o jogador sem caixa; quem escolhia pela
## melhora por giro terminava as 4 h do playtest com caixa). Peça já possuída
## (custa 0) vem antes; empate: a que mais melhora. Cada opção ganha
## "ganho_por_mil": posições médias ganhas a cada 1000 giros (0 = já é sua).
static func ordenar(boas: Array, base: Dictionary, maximo: int) -> Array:
	for o in boas:
		o["ganho"] = float(base.get("media", 0.0)) - float(o["media"])
		o["ganho_por_mil"] = o["ganho"] * 1000.0 / float(o["preco"]) if int(o["preco"]) > 0 else 0.0
	boas.sort_custom(func(x, y):
		if (int(x["preco"]) == 0) != (int(y["preco"]) == 0):
			return int(x["preco"]) == 0
		var gx: float = x["ganho"] / maxf(float(x["preco"]), 1.0)
		var gy: float = y["ganho"] / maxf(float(y["preco"]), 1.0)
		if absf(gx - gy) > 1e-9:
			return gx > gy
		return x["ganho"] > y["ganho"])
	return boas.slice(0, maximo)


## Peças e pneus que o saldo paga, cada um já montado numa cópia do carro.
static func candidatas(dados: Node, jogador: Node, carro: Carro) -> Array:
	var r := []
	for p in dados.lista("pecas"):
		# A blindagem é para a arena: o mecânico da corrida não a sugere.
		if p["categoria"] == Blindagem.CATEGORIA or carro.motivo_recusa(p) != "" \
				or carro.pecas.get(p["categoria"], {}).get("id") == p["id"]:
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
static func avaliar(carreira: Carreira, evento_id: String, uid: int, carro: Carro, amostras: int = -1,
		semente_base: int = SEMENTE_BASE) -> Dictionary:
	if amostras < 0:
		amostras = amostras_para(carreira.dados.evento(evento_id))
	var posicoes := []
	for k in amostras:
		var r := carreira.preparar(evento_id, uid, semente_base + k, false, carro)
		if r.has("erro"):
			return {}
		posicoes.append(r["resultado"]["classificacao"].find("jogador") + 1)
	return _resumir(posicoes)


## avaliar() sem travar a tela (decisão 90: a de uma resistência leva
## segundos): cada corrida é resolvida aos poucos, até `orcamento_ms` por quadro
## de `arvore`. Mesmo resultado; chamar com await.
static func avaliar_aos_poucos(carreira: Carreira, evento_id: String, uid: int, carro: Carro, arvore: SceneTree,
		orcamento_ms: float, amostras: int = -1) -> Dictionary:
	if amostras < 0:
		amostras = amostras_para(carreira.dados.evento(evento_id))
	var posicoes := []
	for k in amostras:
		var p := carreira.iniciar_preparo(evento_id, uid, SEMENTE_BASE + k, false, carro)
		if p.has("erro"):
			return {}
		while not p["andamento"].avancar(orcamento_ms):
			await arvore.process_frame
		posicoes.append(carreira.concluir_preparo(p)["resultado"]["classificacao"].find("jogador") + 1)
	return _resumir(posicoes)


static func _resumir(posicoes: Array) -> Dictionary:
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


## Quando nenhuma peça ou pneu resolve: o carro mais barato da loja que abre
## uma prova ainda não vencida (com as licenças que o jogador tem) que o carro
## atual não pode correr, ou que corre uma das `travadas` (provas em que o
## atual não sai do lugar) com mais potência por peso de fábrica (+5%, o mesmo
## critério do agente de playtest). Não precisa caber no saldo: é a meta para
## juntar. {"carro": dados do carro, "prova": nome da prova, "abre": true se o
## atual não pode correr nela}; {} se nenhum serve.
static func carro_sugerido(dados: Node, jogador: Node, carro: Carro, travadas: Array = []) -> Dictionary:
	var l := carros_candidatos(dados, jogador, carro, travadas, 1)
	return {} if l.is_empty() else l[0]


## Os carros de carro_sugerido, do mais barato ao mais caro, até `maximo`. Os
## que só servem numa travada ("abre" false) passam pela simulação na tela
## antes de aparecer: a potência por peso de fábrica não conta as peças do atual.
static func carros_candidatos(dados: Node, jogador: Node, carro: Carro, travadas: Array, maximo: int) -> Array:
	var pneu: Dictionary = dados.pneu(dados.economia()["pneu_de_fabrica"])
	var fab := Carro.new(carro.base)
	fab.adicionar_pneu(pneu)
	var fa := fab.atributos_efetivos("seco")
	var ppa: float = fa["potencia"] / fa["peso"]
	var possuidos: Array = jogador.garagem.lista().map(func(c): return c.id)
	var abertas: Array = dados.lista("eventos").filter(func(ev):
		return not jogador.vitorias.has(ev["id"]) and not ev["premios"].is_empty())
	var bases: Array = dados.lista("carros").filter(func(b): return not b["id"] in possuidos)
	bases.sort_custom(func(x, y): return int(x["preco"]) < int(y["preco"]))
	var r := []
	for base in bases:
		var teste := Carro.new(base)
		teste.adicionar_pneu(pneu)
		var mais_forte: bool = float(base["potencia"]) / float(base["peso"]) > ppa * 1.05
		for ev in abertas:
			if not Elegibilidade.motivos(teste, ev["restricoes"], jogador.licencas).is_empty():
				continue
			var atual_entra := Elegibilidade.motivos(carro, ev["restricoes"], jogador.licencas).is_empty()
			if not atual_entra or (ev["id"] in travadas and mais_forte):
				r.append({"carro": base, "prova": String(ev["nome"]), "abre": not atual_entra, "evento": ev["id"]})
				break
		if r.size() >= maximo:
			break
	return r
