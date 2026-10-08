class_name Fila
extends RefCounted
## Fila de repetições e progresso offline (docs/plano_mvp.md, decisões 2, 3 e 34).
## Um carro por vez: o jogador escolhe evento, carro e número de repetições.
## Cada corrida leva em tempo real o mesmo que leva simulada. Ao processar,
## todas as corridas que já teriam terminado são aplicadas em lote; o tempo
## ausente conta até `teto_offline_s` (data/carreira.json).
##
## Estado em jogador.fila: {} ou {evento_id, uid, restantes, inicio, semente,
## config}. `config` é a cópia da preparação na inscrição (Carro.configuracao):
## mexer no carro ou numa configuração salva depois não muda corridas já
## programadas. Fila sem `config` (save antigo) usa o carro como está.
##
## Repetir (renda automática) só em prova já vencida; a primeira vitória é um
## desafio, com uma inscrição por vez.

## Intervalo entre processamentos acima do qual houve ausência (app fechado ou
## em segundo plano). Com o app aberto a fila processa a cada segundo. Técnico.
const AUSENCIA_S := 5.0

var carreira: Carreira
var jogador: Node
var teto_offline_s: float
## Corrida em andamento já simulada: a tela e o processamento a cada segundo
## reusam o resultado em vez de simular de novo. Chave inclui os atributos do
## carro, então uma peça instalada no meio invalida o cache.
var _cache_chave := ""
var _cache: Dictionary = {}


func _init(carreira_: Carreira, jogador_: Node, teto_offline_s_: float) -> void:
	carreira = carreira_
	jogador = jogador_
	teto_offline_s = teto_offline_s_


## Começa a fila agora. Retorna "" ou o motivo (carro inelegível etc.).
## `config` vazio: a preparação atual do carro.
func iniciar(evento_id: String, uid: int, repeticoes: int, agora: float, config: Dictionary = {}) -> String:
	if repeticoes < 1:
		return "repetições deve ser ao menos 1"
	if repeticoes > 1 and not jogador.vitorias.has(evento_id):
		return "correr de novo só depois de vencer a corrida uma vez"
	var carro: Carro = jogador.garagem.carro(uid)
	if carro == null:
		return "carro %d não está na garagem" % uid
	var cfg: Dictionary = carro.configuracao() if config.is_empty() else config.duplicate(true)
	cfg.erase("nome")
	cfg["pneus"] = carro.pneus.map(func(p): return p["id"])
	var semente := _nova_semente()
	var f := {"evento_id": evento_id, "uid": uid, "restantes": repeticoes, "inicio": agora, "semente": semente,
			"config": cfg}
	# Segundo piloto da equipe (fase 9): inscrito junto, com a preparação de agora.
	var cu := EquipeJogador.companheiro_para(carreira.dados, jogador, evento_id, uid)
	if cu >= 0:
		var cc: Carro = jogador.garagem.carro(cu)
		var cfg2: Dictionary = cc.configuracao()
		cfg2.erase("nome")
		cfg2["pneus"] = cc.pneus.map(func(p): return p["id"])
		f["companheiro"] = {"uid": cu, "config": cfg2}
	var teste := _preparar(f, false)
	if teste.has("erro"):
		return teste["erro"]
	jogador.fila = f
	jogador.ultimo_processamento = agora
	return ""


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


## A fila acaba quando a corrida em andamento terminar.
func parar_apos_atual() -> void:
	if not jogador.fila.is_empty():
		jogador.fila["restantes"] = 1


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
	var c := _preparar(f, true).duplicate()
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

	var antes := float(jogador.ultimo_processamento)
	var offline := ausencia > AUSENCIA_S
	while not jogador.fila.is_empty():
		var f: Dictionary = jogador.fila
		var c := _preparar(f, false)
		if c.has("erro"):
			rel["erro"] = c["erro"]
			cancelar()
			break
		var fim := float(f["inicio"]) + float(c["duracao"])
		if offline and fim > antes and importante(f):
			# Decisão 34: prova inédita ou etapa de campeonato não corre com o app
			# fechado; na volta, recomeça ao vivo.
			f["inicio"] = agora
			rel["recomecou"] = f["evento_id"]
			break
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


## Corrida que só acontece com o app aberto (decisão 34): prova ainda não vencida
## ou etapa que vale pontos na temporada do campeonato. Repetição de prova vencida
## (renda) roda offline.
func importante(f: Dictionary) -> bool:
	var evento_id: String = f["evento_id"]
	if Prologo.deve_ultima_corrida(carreira.dados, jogador):
		return true  # corrida da história
	if not jogador.vitorias.has(evento_id):
		return true
	var ev: Dictionary = carreira.dados.evento(evento_id)
	var lista := Campeonatos.etapas(carreira.dados, Campeonatos.serie(ev))
	return not lista.is_empty() and lista.find(ev) == int(Campeonatos.estado(jogador, Campeonatos.serie(ev))["etapa"])


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


func _preparar(f: Dictionary, com_amostras: bool) -> Dictionary:
	var carro := carro_inscrito(f)
	var comp := companheiro_inscrito(f)
	var assinatura := "" if carro == null else str(carro.atributos_efetivos("seco")) + str(carro.atributos_efetivos("chuva"))
	if comp != null:
		assinatura += str(comp.atributos_efetivos("seco")) + str(comp.atributos_efetivos("chuva"))
	var chave := "%s|%d|%d|%s" % [f["evento_id"], int(f["uid"]), int(f["semente"]), assinatura]
	if chave == _cache_chave and (not com_amostras or _cache.get("com_amostras", false)):
		return _cache
	var c := carreira.preparar(f["evento_id"], int(f["uid"]), int(f["semente"]), com_amostras, carro, comp)
	if carro == null:
		c = {"erro": "carro %d não está na garagem" % int(f["uid"])}
	c["com_amostras"] = com_amostras
	if not c.has("erro"):
		_cache_chave = chave
		_cache = c
	return c


func _nova_semente() -> int:
	jogador.contador_sementes += 1
	return hash("corrida:%d" % jogador.contador_sementes)
