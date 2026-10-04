class_name Carreira
extends RefCounted
## Disputa de eventos: monta o grid, roda a Simulacao e paga o resultado.
##   - O jogador larga em último, atrás dos adversários na ordem do evento (GT2).
##   - Prêmio em dinheiro por posição a cada disputa; carro-prêmio só na
##     primeira vitória do evento.
##   - Cada corrida disputada conta um dia (rotação de usados, docs/plano_mvp.md).

var dados: Node
var jogador: Node


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
func preparar(evento_id: String, uid: int, semente: int, com_amostras: bool = true) -> Dictionary:
	var ev: Dictionary = dados.evento(evento_id)
	if ev.is_empty():
		return {"erro": "evento %s não existe" % evento_id}
	var carro: Carro = jogador.garagem.carro(uid)
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

	var r := Simulacao.correr(dados.pista(ev["pista"]), participantes, int(ev["voltas"]),
			dados.simulacao(), semente, com_amostras)
	return {"evento_id": evento_id, "uid": uid, "resultado": r, "duracao": r["duracao"]}


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

	return {
		"evento_id": evento_id,
		"classificacao": r["classificacao"],
		"posicao": posicao,
		"premio": premio,
		"carro_premio_uid": carro_premio_uid,
		"resultado": r,
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
