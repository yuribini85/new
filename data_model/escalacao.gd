class_name Escalacao
extends RefCounted
## Escalação (decisão 68): os carros pré-escolhidos para competir. Uma vaga de
## CORRIDA (nas corridas só corre um piloto da equipe) e duas de ARENA (a
## dupla: você e o segundo piloto). Três carros diferentes: um carro não está
## na corrida e na arena ao mesmo tempo. Escalado não se vende.
## jogador.escalacao = {corrida: uid, arena: [uid, uid]} (-1 = vaga vazia).
## Carro que saiu da garagem deixa a vaga vazia sozinho (as leituras conferem).

const VAGAS := ["corrida", "arena1", "arena2"]
const NOMES := {"corrida": "CORRIDA", "arena1": "ARENA 1", "arena2": "ARENA 2"}


## uid na vaga ("corrida", "arena1", "arena2"), ou -1 se vazia.
static func uid(jogador: Node, vaga: String) -> int:
	var e: Dictionary = jogador.escalacao
	var u := -1
	match vaga:
		"corrida":
			u = int(e.get("corrida", -1))
		"arena1", "arena2":
			var a: Array = e.get("arena", [-1, -1])
			u = int(a[0 if vaga == "arena1" else 1]) if a.size() == 2 else -1
	return u if u >= 0 and jogador.garagem.carro(u) != null else -1


static func carro(jogador: Node, vaga: String) -> Carro:
	var u := uid(jogador, vaga)
	return jogador.garagem.carro(u) if u >= 0 else null


## Vaga em que o carro está ("" se em nenhuma).
static func vaga_de(jogador: Node, u: int) -> String:
	for v in VAGAS:
		if u >= 0 and uid(jogador, v) == u:
			return v
	return ""


## Os uids escalados (os que não se vendem).
static func uids(jogador: Node) -> Array:
	return VAGAS.map(func(v): return uid(jogador, v)).filter(func(u): return u >= 0)


## Põe o carro na vaga (-1 esvazia). Devolve "" ou o motivo.
static func definir(jogador: Node, vaga: String, u: int) -> String:
	if not vaga in VAGAS:
		return "vaga desconhecida"
	if u >= 0 and jogador.garagem.carro(u) == null:
		return "carro fora da garagem"
	var corrida_em_andamento: bool = not jogador.fila.is_empty()
	if vaga == "corrida" and corrida_em_andamento:
		return "há uma corrida em andamento: troque depois que ela terminar"
	var atual := vaga_de(jogador, u)
	if u >= 0 and atual != "" and atual != vaga:
		return "esse carro já está na vaga %s" % NOMES[atual]
	var e: Dictionary = jogador.escalacao
	if vaga == "corrida":
		e["corrida"] = u
	else:
		var a: Array = e.get("arena", [-1, -1])
		if a.size() != 2:
			a = [-1, -1]
		a[0 if vaga == "arena1" else 1] = u
		e["arena"] = a
	jogador.escalacao = e
	return ""


## Save antigo ou jogo novo sem escalação: o carro da corrida em andamento (ou
## o carro em uso) vai para a vaga de corrida.
static func migrar(jogador: Node) -> void:
	if jogador.escalacao.is_empty():
		var u := int(jogador.fila["uid"]) if not jogador.fila.is_empty() else int(jogador.carro_ativo)
		jogador.escalacao = {"corrida": u, "arena": [-1, -1]}


## O carro de corrida; vaga vazia com carro livre na garagem: escala o carro em
## uso (ou o primeiro fora da arena), para quem ainda não montou a escalação
## (prólogo, primeiro carro) não ficar parado. null sem carro livre.
static func garantir_corrida(jogador: Node) -> Carro:
	if uid(jogador, "corrida") < 0:
		var arena := [uid(jogador, "arena1"), uid(jogador, "arena2")]
		var livres: Array = jogador.garagem.lista().filter(func(c): return not c.uid in arena)
		if livres.is_empty():
			return null
		var ativo: Array = livres.filter(func(c): return c.uid == int(jogador.carro_ativo))
		definir(jogador, "corrida", (ativo[0] if not ativo.is_empty() else livres[0]).uid)
	return carro(jogador, "corrida")
