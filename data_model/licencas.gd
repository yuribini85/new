class_name Licencas
extends RefCounted
## Testes de tempo de licença: tempo-alvo numa pista com o carro do próprio
## jogador dentro de uma restrição. Licença com contratos (data/contratos.json,
## decisão 4) é concedida pelos contratos (ver Contratos) e ignora os testes;
## sem contratos, quando todos os testes têm ao menos bronze. Não contam dia.

const GRAUS := ["ouro", "prata", "bronze"]
## Estados (decisão 33). LOCKED: falta a anterior ou um requisito; AVAILABLE:
## pode iniciar o treino; TRAINING: treino correndo (conta offline, pelo relógio);
## READY: avaliação aberta (contratos ou testes); COMPLETE: concedida.
const LOCKED := "LOCKED"
const AVAILABLE := "AVAILABLE"
const TRAINING := "TRAINING"
const READY := "READY_FOR_EVALUATION"
const COMPLETE := "COMPLETE"

## Ids do GT2 nos saves antigos -> ids do jogo (decisão 33).
const ID_ANTIGO := {"B": "CLUB", "A": "SPORT", "IC": "NATIONAL", "IB": "INTERNATIONAL", "IA": "PRO"}


static func id_novo(id: String) -> String:
	return ID_ANTIGO.get(id, id)


## "b1" -> "club1"; ids de contrato e já novos ficam como estão.
static func teste_novo(id: String) -> String:
	var letras := id.rstrip("0123456789")
	var novo: String = ID_ANTIGO.get(letras.to_upper(), "")
	if novo == "" or letras != letras.to_lower() or letras.length() == id.length():
		return id
	return novo.to_lower() + id.substr(letras.length())


var dados: Node
var jogador: Node


func _init(dados_: Node, jogador_: Node) -> void:
	dados = dados_
	jogador = jogador_


## Configuração (carreira.json "licencas"): fator do treino, fração das séries
## e a partir de que licença pede campeonato.
func _cfg() -> Dictionary:
	return dados.carreira().get("licencas", {})


## Estado da licença no instante `agora` (segundos Unix; o agente de testes
## passa o próprio relógio de corrida).
func estado(licenca_id: String, agora: float) -> String:
	if licenca_id in jogador.licencas:
		return COMPLETE
	if not requisitos(licenca_id).all(func(r): return r["ok"]):
		return LOCKED
	if not jogador.treinos.has(licenca_id):
		return AVAILABLE
	return TRAINING if restante(licenca_id, agora) > 0.0 else READY


## Segundos de treino que faltam (0 se não começou ou já terminou).
func restante(licenca_id: String, agora: float) -> float:
	if not jogador.treinos.has(licenca_id):
		return 0.0
	return maxf(0.0, float(jogador.treinos[licenca_id]) + treino_s(licenca_id) - agora)


## Duração do treino: soma dos tempos de bronze dos testes × fator_treino
## (a confirmar no playtest). Sem testes (ELITE: a S do GT2 não tem), a da anterior.
func treino_s(licenca_id: String) -> float:
	var lic: Dictionary = dados.item("licencas", licenca_id)
	var soma := 0.0
	for t in lic.get("testes", []):
		if t["tempos"]["bronze"] != null:
			soma += float(t["tempos"]["bronze"])
	if soma <= 0.0 and lic.get("requisito") != null:
		return treino_s(String(lic["requisito"]))
	return soma * float(_cfg().get("fator_treino", 1.0))


## Requisitos com o status de cada um: [{texto, ok}].
## Licença anterior; vitória em ao menos uma etapa de `fracao_series` das séries
## da anterior; a partir de `campeonato_desde`, um título de campeonato da
## anterior (se a anterior tiver campeonato).
func requisitos(licenca_id: String) -> Array:
	var lic: Dictionary = dados.item("licencas", licenca_id)
	var r := []
	var anterior = lic.get("requisito")
	if anterior == null:
		return r
	var nome_ant: String = dados.item("licencas", anterior).get("nome", anterior)
	r.append({"texto": nome_ant, "ok": anterior in jogador.licencas})
	var series := {}
	for e in dados.lista("eventos"):
		if e["restricoes"].get("licenca", "") == anterior:
			var sr := Campeonatos.serie(e)
			series[sr] = series.get(sr, false) or jogador.vitorias.has(e["id"])
	if not series.is_empty():
		var pede := ceili(series.size() * float(_cfg().get("fracao_series", 0.0)))
		var tem := series.values().filter(func(x): return x).size()
		if pede > 0:
			r.append({"texto": "vencer em %d de %d séries da %s (%d)" % [pede, series.size(), nome_ant, tem],
					"ok": tem >= pede})
	var ordem: Array = dados.lista("licencas").map(func(l): return l["id"])
	var desde := ordem.find(String(_cfg().get("campeonato_desde", "")))
	if desde >= 0 and ordem.find(licenca_id) >= desde:
		var camps := series.keys().filter(func(sr): return not Campeonatos.etapas(dados, sr).is_empty())
		if not camps.is_empty():
			r.append({"texto": "um título de campeonato da %s" % nome_ant,
					"ok": camps.any(func(sr): return jogador.titulos.has(sr))})
	return r


## Começa o treino (preço do GT2: grátis). "" ou o motivo de não poder.
func iniciar_treino(licenca_id: String, agora: float) -> String:
	var st := estado(licenca_id, agora)
	if st != AVAILABLE:
		return "treino indisponível (%s)" % st
	var preco := int(dados.item("licencas", licenca_id).get("preco", 0))
	if preco > 0 and not jogador.economia.debitar(preco):
		return "saldo insuficiente"
	jogador.treinos[licenca_id] = agora
	return ""


## A avaliação (testes ou contratos) só abre depois do treino; refazer para
## melhorar o grau continua possível depois de concedida.
func pode_avaliar(licenca_id: String, agora: float) -> bool:
	return estado(licenca_id, agora) in [READY, COMPLETE]


## Retorna {"erro"} ou {"tempo", "grau" ("" se reprovado), "licenca_concedida"}.
func fazer_teste(licenca_id: String, teste_id: String, uid: int, semente: int,
		agora: float = Time.get_unix_time_from_system()) -> Dictionary:
	var lic: Dictionary = dados.item("licencas", licenca_id)
	if lic.get("requisito") != null and not lic["requisito"] in jogador.licencas:
		return {"erro": "exige a licença %s" % lic["requisito"]}
	if not pode_avaliar(licenca_id, agora):
		return {"erro": "termine o treino da %s antes da avaliação" % lic.get("nome", licenca_id)}
	var teste := _teste(lic, teste_id)
	if teste.is_empty():
		return {"erro": "teste %s não existe em %s" % [teste_id, licenca_id]}
	var carro: Carro = jogador.garagem.carro(uid)
	if carro == null:
		return {"erro": "carro %d não está na garagem" % uid}
	var motivos := Elegibilidade.motivos(carro, teste.get("restricoes", {}), jogador.licencas)
	if not motivos.is_empty():
		return {"erro": ", ".join(motivos)}

	var r := Simulacao.correr(dados.pista(teste["pista"]), [{
		"id": "jogador",
		"atributos": carro.atributos_efetivos(teste["condicao"]),
		"piloto": dados.piloto(dados.carreira()["piloto_jogador"]),
	}], int(teste["voltas"]), dados.simulacao(), semente)
	var tempo: float = r["carros"]["jogador"]["tempo_total"]
	var grau := ""
	if r["carros"]["jogador"]["terminou"]:
		for g in GRAUS:
			if tempo <= float(teste["tempos"][g]):
				grau = g
				break
	_guardar_melhor(teste_id, grau)
	var concedida := false
	if not licenca_id in jogador.licencas and Contratos.da_licenca(dados, licenca_id).is_empty() and _completa(lic):
		jogador.licencas.append(licenca_id)
		concedida = true
	return {"tempo": tempo, "grau": grau, "licenca_concedida": concedida}


func _teste(lic: Dictionary, teste_id: String) -> Dictionary:
	for t in lic["testes"]:
		if t["id"] == teste_id:
			return t
	return {}


func _guardar_melhor(teste_id: String, grau: String) -> void:
	if grau == "":
		return
	var atual: String = jogador.graus_licenca.get(teste_id, "")
	if atual == "" or GRAUS.find(grau) < GRAUS.find(atual):
		jogador.graus_licenca[teste_id] = grau


func _completa(lic: Dictionary) -> bool:
	for t in lic["testes"]:
		if not jogador.graus_licenca.has(t["id"]):
			return false
	return true
