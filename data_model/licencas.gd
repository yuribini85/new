class_name Licencas
extends RefCounted
## Testes de licença (docs/plano_mvp.md, decisão 4): tempo-alvo numa pista com
## o carro do próprio jogador dentro de uma restrição. A licença é concedida
## quando todos os testes têm ao menos bronze. Testes não contam dia.

const GRAUS := ["ouro", "prata", "bronze"]

var dados: Node
var jogador: Node


func _init(dados_: Node, jogador_: Node) -> void:
	dados = dados_
	jogador = jogador_


## Retorna {"erro"} ou {"tempo", "grau" ("" se reprovado), "licenca_concedida"}.
func fazer_teste(licenca_id: String, teste_id: String, uid: int, semente: int) -> Dictionary:
	var lic: Dictionary = dados.item("licencas", licenca_id)
	if lic.get("requisito") != null and not lic["requisito"] in jogador.licencas:
		return {"erro": "exige a licença %s" % lic["requisito"]}
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
	if not licenca_id in jogador.licencas and _completa(lic):
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
