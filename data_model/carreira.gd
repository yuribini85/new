class_name Carreira
extends RefCounted
## Disputa de eventos: monta o grid, roda a Simulacao e paga o resultado.
##   - O jogador larga em último, atrás dos adversários na ordem do evento (GT2).
##   - Prêmio em dinheiro por posição a cada disputa; carro-prêmio só na
##     primeira vitória do evento.
##   - Cada corrida disputada conta um dia (rotação de usados, docs/plano_mvp.md).

var dados: Node
var jogador: Node
## Quantas corridas foram simuladas (para medir custo; ver Fila).
var simulacoes := 0


func _init(dados_: Node, jogador_: Node) -> void:
	dados = dados_
	jogador = jogador_


## Disputa e aplica o resultado na hora. Retorna {"erro"} ou o mesmo que aplicar().
func disputar(evento_id: String, uid: int, semente: int) -> Dictionary:
	var corrida := preparar(evento_id, uid, semente)
	if corrida.has("erro"):
		return corrida
	return aplicar(corrida)


## Simula sem alterar nada no jogador. Mesma semente, mesmo resultado — a fila
## offline depende disso para recalcular a corrida em andamento após o load.
## Retorna {"erro"} ou {"evento_id", "uid", "resultado", "duracao"}.
## com_amostras = false (fila offline) dispensa as posições usadas só pela tela.
## `hipotetico` simula outro carro no lugar do da garagem (Mecanico: "e se eu
## comprasse esta peça?") sem alterar nada.
func preparar(evento_id: String, uid: int, semente: int, com_amostras: bool = true,
		hipotetico: Carro = null) -> Dictionary:
	var ev: Dictionary = dados.evento(evento_id)
	if ev.is_empty():
		return {"erro": "evento %s não existe" % evento_id}
	var carro: Carro = hipotetico if hipotetico != null else jogador.garagem.carro(uid)
	if carro == null:
		return {"erro": "carro %d não está na garagem" % uid}
	var motivos := Elegibilidade.motivos(carro, ev["restricoes"], jogador.licencas)
	if not motivos.is_empty():
		return {"erro": ", ".join(motivos)}

	var condicao: String = ev["condicao"]
	var participantes := []
	for i in ev["adversarios"].size():
		participantes.append(_adversario(ev["adversarios"][i], i, condicao))
	participantes.append({
		"id": "jogador",
		"atributos": carro.atributos_efetivos(condicao),
		"piloto": dados.piloto(dados.carreira()["piloto_jogador"]),
	})

	simulacoes += 1
	var r := Simulacao.correr(dados.pista(ev["pista"]), participantes, int(ev["voltas"]),
			dados.simulacao(), semente, com_amostras)
	return {"evento_id": evento_id, "uid": uid, "resultado": r, "duracao": r["duracao"]}


## Sobrenomes fictícios dos pilotos rivais (só apresentação: a simulação usa
## o perfil do piloto do evento). Fixos por prova e posição no grid.
const PILOTOS := ["Okada", "Brandt", "Moreau", "Ferraz", "Tanaka", "Kowalski", "Reyes", "Lindqvist",
		"Hale", "Ito", "Novak", "Duarte", "Sato", "Keller", "Varga", "Lacroix", "Mendes", "Harlow"]


## Piloto de um rival ("adv<i>_<carro>") nesta prova; "" para o jogador.
static func nome_piloto(evento_id: String, id: String) -> String:
	if not id.begins_with("adv"):
		return ""
	var i := int(id.trim_prefix("adv").split("_", true, 1)[0])
	var base := posmod(hash(evento_id), PILOTOS.size())
	# Passo primo com a lista: pilotos diferentes no mesmo grid.
	return PILOTOS[(base + i * 7) % PILOTOS.size()]


## "Piloto (carro)" para listas: distingue rivais com o mesmo modelo.
func rotulo_participante(evento_id: String, id: String, uid: int) -> String:
	if id == "jogador":
		return nome_participante(id, uid)
	return "%s (%s)" % [nome_piloto(evento_id, id), Aba.nome_curto(nome_participante(id, uid))]


## Nome do carro de um participante ("jogador" ou "adv<i>_<carro>").
func nome_participante(id: String, uid: int) -> String:
	if id == "jogador":
		var c: Carro = jogador.garagem.carro(uid)
		return "Você" if c == null else "Você (%s)" % c.base["nome"]
	return dados.carro(id.split("_", true, 1)[1]).get("nome", id)


## Atributos efetivos (com peças e pneus) de um participante na condição da
## prova: o jogador pelo carro `uid`, o adversário pela definição do evento.
func atributos_participante(evento_id: String, id: String, uid: int) -> Dictionary:
	var ev: Dictionary = dados.evento(evento_id)
	if id == "jogador":
		var c: Carro = jogador.garagem.carro(uid)
		return {} if c == null else c.atributos_efetivos(ev["condicao"])
	var i := int(id.trim_prefix("adv").split("_", true, 1)[0])
	if ev.is_empty() or i < 0 or i >= ev["adversarios"].size():
		return {}
	return _adversario(ev["adversarios"][i], i, ev["condicao"])["atributos"]


## Atributos de fábrica do carro de um adversário ("adv<i>_<carro>").
func carro_participante(id: String) -> Dictionary:
	return dados.carro(id.split("_", true, 1)[1]) if id.begins_with("adv") else {}


## Paga prêmio, entrega carro-prêmio e conta o dia.
## Retorna {"evento_id", "classificacao", "posicao", "premio", "carro_premio_uid", "resultado"}.
func aplicar(corrida: Dictionary) -> Dictionary:
	var evento_id: String = corrida["evento_id"]
	var ev: Dictionary = dados.evento(evento_id)
	var r: Dictionary = corrida["resultado"]
	var posicao: int = r["classificacao"].find("jogador") + 1
	var premio := 0
	if posicao <= ev["premios"].size():
		premio = int(ev["premios"][posicao - 1])
	jogador.economia.creditar(premio)

	var carro_premio_uid := -1
	if posicao == 1:
		var primeira: bool = not jogador.vitorias.has(evento_id)
		jogador.vitorias[evento_id] = jogador.vitorias.get(evento_id, 0) + 1
		if primeira and ev.get("carro_premio") != null:
			var premiado := Carro.new(dados.carro(ev["carro_premio"]))
			premiado.adicionar_pneu(dados.pneu(dados.economia()["pneu_de_fabrica"]))
			carro_premio_uid = jogador.garagem.adicionar(premiado)
	jogador.dias += 1
	var tempo: float = r["carros"]["jogador"]["tempo_total"] if r["carros"]["jogador"]["terminou"] else 0.0
	var anterior: Dictionary = jogador.historico.get(evento_id, {}).duplicate()
	jogador.historico[evento_id] = _historico(anterior, posicao, tempo)

	return {
		"anterior": anterior,
		"recorde": tempo > 0.0 and (anterior.is_empty() or anterior["melhor_tempo"] <= 0.0 or tempo < anterior["melhor_tempo"]),
		"evento_id": evento_id,
		"classificacao": r["classificacao"],
		"posicao": posicao,
		"premio": premio,
		"carro_premio_uid": carro_premio_uid,
		"resultado": r,
	}


static func _historico(h: Dictionary, posicao: int, tempo: float) -> Dictionary:
	if h.is_empty():
		return {"corridas": 1, "melhor_pos": posicao, "melhor_tempo": tempo, "ultima_pos": posicao, "ultimo_tempo": tempo}
	return {
		"corridas": int(h["corridas"]) + 1,
		"melhor_pos": mini(int(h["melhor_pos"]), posicao),
		"melhor_tempo": tempo if h["melhor_tempo"] <= 0.0 or (tempo > 0.0 and tempo < h["melhor_tempo"]) else h["melhor_tempo"],
		"ultima_pos": posicao,
		"ultimo_tempo": tempo,
	}


func _adversario(adv: Dictionary, indice: int, condicao: String) -> Dictionary:
	var c := Carro.new(dados.carro(adv["carro"]))
	for peca_id in adv.get("pecas", []):
		c.instalar(dados.peca(peca_id))
	var pneus: Array = adv.get("pneus", [])
	if pneus.is_empty():
		pneus = [dados.economia()["pneu_de_fabrica"]]
	for pneu_id in pneus:
		c.adicionar_pneu(dados.pneu(pneu_id))
	return {
		"id": "adv%d_%s" % [indice, adv["carro"]],
		"atributos": c.atributos_efetivos(condicao),
		"piloto": dados.piloto(adv["piloto"]),
	}
