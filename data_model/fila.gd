class_name Fila
extends RefCounted
## Fila de repetições e progresso offline (docs/plano_mvp.md, decisões 2 e 3).
## Um carro por vez: o jogador escolhe evento, carro e número de repetições.
## Cada corrida leva em tempo real o mesmo que leva simulada. Ao processar,
## todas as corridas que já teriam terminado são aplicadas em lote; o tempo
## ausente conta até `teto_offline_s` (data/carreira.json).
##
## Estado em jogador.fila: {} ou {evento_id, uid, restantes, inicio, semente}.

var carreira: Carreira
var jogador: Node
var teto_offline_s: float


func _init(carreira_: Carreira, jogador_: Node, teto_offline_s_: float) -> void:
	carreira = carreira_
	jogador = jogador_
	teto_offline_s = teto_offline_s_


## Começa a fila agora. Retorna "" ou o motivo (carro inelegível etc.).
func iniciar(evento_id: String, uid: int, repeticoes: int, agora: float) -> String:
	if repeticoes < 1:
		return "repetições deve ser ao menos 1"
	var semente := _nova_semente()
	var teste := carreira.preparar(evento_id, uid, semente)
	if teste.has("erro"):
		return teste["erro"]
	jogador.fila = {"evento_id": evento_id, "uid": uid, "restantes": repeticoes, "inicio": agora, "semente": semente}
	jogador.ultimo_processamento = agora
	return ""


func cancelar() -> void:
	jogador.fila = {}


## A corrida em andamento (para a visualização) ou {} se a fila está vazia.
## Inclui "decorrido": segundos desde o início dela.
func corrida_atual(agora: float) -> Dictionary:
	var f: Dictionary = jogador.fila
	if f.is_empty():
		return {}
	var c := carreira.preparar(f["evento_id"], f["uid"], f["semente"])
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

	while not jogador.fila.is_empty():
		var f: Dictionary = jogador.fila
		var c := carreira.preparar(f["evento_id"], f["uid"], f["semente"])
		if c.has("erro"):
			rel["erro"] = c["erro"]
			cancelar()
			break
		var fim := float(f["inicio"]) + float(c["duracao"])
		if fim > limite:
			break
		var res := carreira.aplicar(c)
		res.erase("resultado")
		rel["corridas"].append(res)
		rel["premio_total"] += res["premio"]
		if res["carro_premio_uid"] > 0:
			rel["carros_premio"].append(res["carro_premio_uid"])
		f["restantes"] = int(f["restantes"]) - 1
		if f["restantes"] <= 0:
			cancelar()
		else:
			f["inicio"] = fim
			f["semente"] = _nova_semente()
	jogador.ultimo_processamento = agora
	return rel


func _nova_semente() -> int:
	jogador.contador_sementes += 1
	return hash("corrida:%d" % jogador.contador_sementes)
