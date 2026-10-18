class_name Fila
extends RefCounted
## A corrida em andamento (decisão 68: uma por vez, sem fila de repetições).
## O jogador escolhe evento e carro; a corrida leva em tempo real o mesmo que
## leva simulada e, depois de iniciada, termina mesmo com o app fechado (o
## tempo ausente conta até `teto_offline_s`, data/carreira.json). Fora isso,
## offline só rende o patrocínio.
##
## Estado em jogador.fila: {} ou {evento_id, uid, restantes, inicio, semente,
## config}. `config` é a cópia da preparação na inscrição (Carro.configuracao):
## mexer no carro ou numa configuração salva depois não muda corridas já
## programadas. Fila sem `config` (save antigo) usa o carro como está.

## Intervalo entre processamentos acima do qual houve ausência (app fechado ou
## em segundo plano). Com o app aberto a fila processa a cada segundo. Técnico.
const AUSENCIA_S := 5.0
## Quanto de cada quadro a simulação de uma corrida pode usar na tela, quando
## resolvida aos poucos (decisão 90). Técnico: ~4 ms deixa folga num quadro de
## 16 ms em aparelho fraco.
const FATIA_MS := 4.0

var carreira: Carreira
var jogador: Node
var teto_offline_s: float
## Corrida em andamento já simulada: a tela e o processamento a cada segundo
## reusam o resultado em vez de simular de novo. Chave inclui os atributos do
## carro, então uma peça instalada no meio invalida o cache.
var _cache_chave := ""
var _cache: Dictionary = {}
## Corrida em andamento sendo resolvida aos poucos, entre quadros (decisão 90):
## {chave, preparo: Carreira.iniciar_preparo()} ou {}. Pronta, vai para o cache.
var _pendente: Dictionary = {}
## Prova, carro e semente do resultado no cache: com uma ordem nova (momento de
## decisão) a tela segue mostrando o resultado anterior, igual até a ordem
## valer, enquanto o novo é resolvido aos poucos.
var _cache_base := ""
## Sobe a cada resultado novo no cache (a tela recarrega as amostras).
var versao := 0
## Momento de decisão à frente (MomentosCorrida): a corrida refeita com cada
## escolha, resolvida aos poucos depois da principal, para a tela saber antes se
## a escolha muda o duelo e, escolhida, trocar o resultado na hora.
## id -> {chave, ordem, preparo} ou {chave, ordem, resultado}.
var _previsoes := {}


func _init(carreira_: Carreira, jogador_: Node, teto_offline_s_: float) -> void:
	carreira = carreira_
	jogador = jogador_
	teto_offline_s = teto_offline_s_


## Começa a fila agora. Retorna "" ou o motivo (carro inelegível etc.).
## `config` vazio: a preparação atual do carro.
func iniciar(evento_id: String, uid: int, repeticoes: int, agora: float, config: Dictionary = {}) -> String:
	if repeticoes != 1:
		return "uma corrida por vez"
	var carro: Carro = jogador.garagem.carro(uid)
	if carro == null:
		return "carro %d não está na garagem" % uid
	var cfg: Dictionary = carro.configuracao() if config.is_empty() else config.duplicate(true)
	cfg.erase("nome")
	cfg["pneus"] = carro.pneus.map(func(p): return p["id"])
	var semente := _nova_semente()
	var f := {"evento_id": evento_id, "uid": uid, "restantes": repeticoes, "inicio": agora, "semente": semente,
			"config": cfg, "piloto": EquipeJogador.piloto_do_jogador(carreira.dados, jogador),
			"contratados": EquipeJogador.contratados(jogador)}
	# Nas corridas só corre um piloto da equipe (decisão 68). A inscrição só
	# confere e monta o grid; a corrida (com as amostras da tela) é resolvida aos
	# poucos por avancar_preparo(), ou de uma vez por quem pedir o resultado antes.
	var k := _chave(f)
	if k.is_empty():
		return "carro %d não está na garagem" % uid
	var p := carreira.iniciar_preparo(f["evento_id"], uid, semente, true, k["carro"], k["comp"], k["piloto"])
	if p.has("erro"):
		return p["erro"]
	_pendente = {"chave": k["chave"], "preparo": p}
	jogador.fila = f
	jogador.ultimo_processamento = agora
	return ""


## A corrida em andamento já está resolvida (com as amostras da tela, se
## `com_amostras`), e as funções que a leem respondem sem simular. Se não, a
## resolução aos poucos começa (ou segue) e a resposta é false: a tela espera
## e chama de novo. Fila vazia ou inválida (o erro sai de processar): true.
func pronta(com_amostras: bool = true) -> bool:
	var f: Dictionary = jogador.fila
	if f.is_empty():
		return true
	var k := _chave(f)
	if k.is_empty():
		return true
	if k["chave"] == _cache_chave and (not com_amostras or _cache.get("com_amostras", false)):
		return true
	if not _pendente.is_empty() and _pendente["chave"] == k["chave"]:
		return false
	var p := carreira.iniciar_preparo(f["evento_id"], int(f["uid"]), int(f["semente"]), true,
			k["carro"], k["comp"], k["piloto"])
	if p.has("erro"):
		_pendente = {}
		return true
	_pendente = {"chave": k["chave"], "preparo": p}
	return false


## Avança a resolução aos poucos da corrida em andamento por até `orcamento_ms`
## (a principal chama a cada quadro). true = nada pendente.
## As previsões dos momentos (prever) usam o que sobrar do orçamento; o
## retorno só fala da corrida em andamento.
func avancar_preparo(orcamento_ms: float) -> bool:
	if _pendente.is_empty():
		_avancar_previsoes(orcamento_ms)
		return true
	var t0 := Time.get_ticks_usec()
	var p: Dictionary = _pendente["preparo"]
	if not p["andamento"].avancar(orcamento_ms):
		return false
	_concluir_pendente()
	_avancar_previsoes(orcamento_ms - (Time.get_ticks_usec() - t0) / 1000.0)
	return true


## Começa a refazer a corrida em andamento com cada ordem (id -> ordem de
## MomentosCorrida.ordem), no lugar das previsões anteriores.
func prever(ordens: Dictionary) -> void:
	_previsoes = {}
	var f: Dictionary = jogador.fila
	if f.is_empty():
		return
	for id in ordens:
		var g := f.duplicate()
		g["piloto"] = _com_ordem(f, ordens[id])
		var k := _chave(g)
		if k.is_empty():
			continue
		var p := carreira.iniciar_preparo(f["evento_id"], int(f["uid"]), int(f["semente"]), true,
				k["carro"], k["comp"], k["piloto"])
		if not p.has("erro"):
			_previsoes[id] = {"chave": k["chave"], "ordem": ordens[id], "preparo": p}


## O resultado da corrida refeita com a escolha `id`, ou {} (ainda sendo
## resolvida, ou sem previsão).
func previsao(id: String) -> Dictionary:
	var pv: Dictionary = _previsoes.get(id, {})
	return pv.get("resultado", {})


func cancelar_previsoes() -> void:
	_previsoes = {}


func _avancar_previsoes(orcamento_ms: float) -> void:
	for id in _previsoes:
		if orcamento_ms <= 0.0:
			return
		var pv: Dictionary = _previsoes[id]
		if pv.has("resultado"):
			continue
		var t0 := Time.get_ticks_usec()
		if pv["preparo"]["andamento"].avancar(orcamento_ms):
			var c := carreira.concluir_preparo(pv["preparo"])
			c["com_amostras"] = true
			pv.erase("preparo")
			pv["resultado"] = c["resultado"]
			pv["corrida"] = c
		orcamento_ms -= (Time.get_ticks_usec() - t0) / 1000.0


func _com_ordem(f: Dictionary, ordem: Dictionary) -> Dictionary:
	var piloto: Dictionary = f["piloto"].duplicate(true) if f.get("piloto") is Dictionary and not f["piloto"].is_empty() \
			else EquipeJogador.piloto_do_jogador(carreira.dados, jogador)
	piloto["ordens"] = Array(piloto.get("ordens", [])) + [ordem]
	return piloto


func _concluir_pendente() -> Dictionary:
	var c := carreira.concluir_preparo(_pendente["preparo"])
	c["com_amostras"] = true
	_guardar(_pendente["chave"], c)
	_pendente = {}
	return c


func _guardar(chave: String, c: Dictionary) -> void:
	_cache_chave = chave
	_cache = c
	_cache_base = chave.substr(0, chave.find("|", chave.find("|", chave.find("|") + 1) + 1))
	versao += 1


## Momento de decisão (MomentosCorrida): a ordem entra no piloto da corrida em
## andamento, que é refeita aos poucos com ela; antes da ordem valer, nada muda.
## Gravada na fila, vale também se a corrida terminar com o app fechado.
func ordenar(ordem: Dictionary) -> void:
	var f: Dictionary = jogador.fila
	if f.is_empty():
		return
	f["piloto"] = _com_ordem(f, ordem)
	# Já prevista (o momento foi resolvido antes de aparecer): vale na hora.
	var k := _chave(f)
	for id in _previsoes:
		var pv: Dictionary = _previsoes[id]
		if pv.has("corrida") and not k.is_empty() and pv["chave"] == k["chave"]:
			_pendente = {}
			_guardar(pv["chave"], pv["corrida"])
			break
	_previsoes = {}
	pronta()


## Faz a corrida em andamento terminar agora (botão de teste da demo).
func adiantar(agora: float) -> void:
	var f: Dictionary = jogador.fila
	if f.is_empty():
		return
	var c := _preparar(f, false)
	if not c.has("erro"):
		f["inicio"] = agora - float(c["duracao"]) - 0.01
		jogador.ultimo_processamento = maxf(float(jogador.ultimo_processamento), agora)  # app aberto


func cancelar() -> void:
	jogador.fila = {}


## Duração (s) da corrida em andamento, ou 0. Base da estimativa da fila.
func duracao_atual() -> float:
	if jogador.fila.is_empty():
		return 0.0
	var c := _preparar(jogador.fila, false)
	return 0.0 if c.has("erro") else float(c["duracao"])


## A corrida em andamento (para a visualização) ou {} se a fila está vazia.
## Inclui "decorrido": segundos desde o início dela.
func corrida_atual(agora: float) -> Dictionary:
	var f: Dictionary = jogador.fila
	if f.is_empty():
		return {}
	var c: Dictionary
	var k := _chave(f)
	if not k.is_empty() and not _pendente.is_empty() and _pendente["chave"] == k["chave"] \
			and _cache.get("com_amostras", false) and k["chave"].begins_with(_cache_base + "|"):
		c = _cache.duplicate()  # ordem nova ainda sendo resolvida: o anterior serve
	else:
		c = _preparar(f, true).duplicate()
	if c.has("erro"):
		return {}
	c["decorrido"] = agora - float(f["inicio"])
	return c


## Aplica as corridas concluídas até `agora`. Retorna o relatório:
## {"corridas": [aplicar()...], "premio_total", "carros_premio": [uid], "erro", "tempo_perdido_s"}.
func processar(agora: float) -> Dictionary:
	var rel := {"corridas": [], "premio_total": 0, "carros_premio": [], "erro": "", "tempo_perdido_s": 0.0}
	var ausencia := maxf(agora - float(jogador.ultimo_processamento), 0.0)
	var excesso := maxf(ausencia - teto_offline_s, 0.0)
	var limite := agora - excesso
	if not jogador.fila.is_empty() and excesso > 0.0:
		# O tempo acima do teto não existe para a fila: ela continua de onde parou.
		jogador.fila["inicio"] = float(jogador.fila["inicio"]) + excesso
		limite = agora
		rel["tempo_perdido_s"] = excesso

	var offline := ausencia > AUSENCIA_S
	while not jogador.fila.is_empty():
		var f: Dictionary = jogador.fila
		var c := _preparar(f, false)
		if c.has("erro"):
			rel["erro"] = c["erro"]
			cancelar()
			break
		var fim := float(f["inicio"]) + float(c["duracao"])
		if fim > limite:
			break
		var res := carreira.aplicar(c)
		# Resumo para o relatório pós-corrida, sem as amostras (pesadas).
		var cr: Dictionary = res["resultado"]["carros"]
		var vencedor: String = res["classificacao"][0]
		res["uid"] = int(f["uid"])
		# Para refazer esta corrida (diagnóstico): semente e preparação inscrita.
		res["semente"] = int(f["semente"])
		if f.get("config") is Dictionary:
			res["config"] = f["config"].duplicate(true)
		res["vencedor"] = vencedor
		# Playtest (RegistroSessao): tempo de corrida e se rodou com o app fechado.
		res["duracao"] = float(c["duracao"])
		res["offline"] = offline
		res["tempo_vencedor"] = cr[vencedor]["tempo_total"]
		res["tempo_jogador"] = cr["jogador"]["tempo_total"]
		res["total"] = res["classificacao"].size()
		# Classificação completa com tempos, para a tela de resultado.
		res["tabela"] = res["classificacao"].map(func(id): return {
			"id": id, "tempo": cr[id]["tempo_total"], "terminou": cr[id]["terminou"]})
		res.erase("resultado")
		jogador.ultima_corrida = res
		res["dia"] = jogador.dias
		rel["corridas"].append(res)
		rel["premio_total"] += res["premio"]
		if res["carro_premio_uid"] > 0:
			rel["carros_premio"].append(res["carro_premio_uid"])
		f["posicoes"] = f.get("posicoes", []) + [res["posicao"]]
		f["restantes"] = int(f["restantes"]) - 1
		if f["restantes"] <= 0:
			cancelar()
		else:
			f["inicio"] = fim
			f["semente"] = _nova_semente()
	# Relógio voltando (ajuste manual, fuso) não pode virar "ausência" depois.
	jogador.ultimo_processamento = maxf(float(jogador.ultimo_processamento), agora)
	return rel


## Carro como foi inscrito: o da garagem com a configuração guardada na fila.
func carro_inscrito(f: Dictionary) -> Carro:
	var carro: Carro = jogador.garagem.carro(int(f["uid"]))
	if carro != null and f.get("config") is Dictionary:
		carro = carro.com_configuracao(f["config"], carreira.dados.peca, carreira.dados.pneu)
	return carro


## Carro do companheiro como foi inscrito (null se ele não corre ou saiu da garagem).
func companheiro_inscrito(f: Dictionary) -> Carro:
	var cp = f.get("companheiro")
	if not cp is Dictionary:
		return null
	var carro: Carro = jogador.garagem.carro(int(cp["uid"]))
	if carro != null and cp.get("config") is Dictionary:
		carro = carro.com_configuracao(cp["config"], carreira.dados.peca, carreira.dados.pneu)
	return carro


## Chave do cache e o que a corrida precisa: {chave, carro, comp, piloto}; {}
## se o carro inscrito saiu da garagem.
func _chave(f: Dictionary) -> Dictionary:
	var carro := carro_inscrito(f)
	if carro == null:
		return {}
	var comp := companheiro_inscrito(f)
	var assinatura := str(carro.atributos_efetivos("seco")) + str(carro.atributos_efetivos("chuva"))
	if comp != null:
		assinatura += str(comp.atributos_efetivos("seco")) + str(comp.atributos_efetivos("chuva"))
	var piloto: Dictionary = f.get("piloto", {}) if f.get("piloto") is Dictionary else {}
	assinatura += str(piloto)
	return {"chave": "%s|%d|%d|%s" % [f["evento_id"], int(f["uid"]), int(f["semente"]), assinatura],
			"carro": carro, "comp": comp, "piloto": piloto}


func _preparar(f: Dictionary, com_amostras: bool) -> Dictionary:
	var k := _chave(f)
	if k.is_empty():
		return {"erro": "carro %d não está na garagem" % int(f["uid"])}
	var chave: String = k["chave"]
	if chave == _cache_chave and (not com_amostras or _cache.get("com_amostras", false)):
		return _cache
	# Já sendo resolvida aos poucos: termina agora, sem recomeçar do zero.
	if not _pendente.is_empty() and _pendente["chave"] == chave:
		return _concluir_pendente()
	var c := carreira.preparar(f["evento_id"], int(f["uid"]), int(f["semente"]), com_amostras,
			k["carro"], k["comp"], k["piloto"])
	c["com_amostras"] = com_amostras
	if not c.has("erro"):
		_guardar(chave, c)
	return c


func _nova_semente() -> int:
	jogador.contador_sementes += 1
	return hash("corrida:%d" % jogador.contador_sementes)
