class_name Carro
extends RefCounted
## Carro na garagem (do jogador ou de um adversário). Atributos base vêm de
## data/carros.json; peças de data/pecas.json; pneus de data/pneus.json.
## Aqui só existem as regras de combinação — nenhum número de balanceamento.

const ATRIBUTOS := ["potencia", "peso", "aderencia", "freio", "velocidade_max"]
const TRACOES := ["FF", "FR", "MR", "RR", "4WD"]
const OPS := ["soma", "mult"]

var id: String
## Identificador da unidade na garagem; o jogador pode ter dois do mesmo modelo.
var uid: int = -1
var base: Dictionary
## Peças compradas para este carro (ids). Reinstalar uma peça possuída é grátis.
var pecas_possuidas: Array = []
## categoria -> peça instalada. Uma peça por categoria, como no GT2.
var pecas: Dictionary = {}
## Compostos possuídos. O piloto de IA escolhe sozinho conforme a condição.
var pneus: Array = []


func _init(dados_carro: Dictionary) -> void:
	id = dados_carro["id"]
	base = dados_carro


## Retorna "" se a peça pode ser instalada, ou o motivo da recusa.
func motivo_recusa(peca: Dictionary) -> String:
	var tracoes: Array = peca.get("tracao_permitida", [])
	if not tracoes.is_empty() and not base["tracao"] in tracoes:
		return "peça %s não serve para tração %s" % [peca["id"], base["tracao"]]
	var carros: Array = peca.get("carros_permitidos", [])
	if not carros.is_empty() and not id in carros:
		return "peça %s não serve para o carro %s" % [peca["id"], id]
	return ""


## Instala substituindo a peça da mesma categoria. Retorna false se recusada.
func instalar(peca: Dictionary) -> bool:
	if motivo_recusa(peca) != "":
		return false
	pecas[peca["categoria"]] = peca
	return true


func remover(categoria: String) -> void:
	pecas.erase(categoria)


func adicionar_pneu(pneu: Dictionary) -> void:
	for p in pneus:
		if p["id"] == pneu["id"]:
			return
	pneus.append(pneu)


## O composto possuído com maior aderência na condição. Vazio se não há pneu.
func escolher_pneu(condicao: String) -> Dictionary:
	var melhor := {}
	for p in pneus:
		if melhor.is_empty() or p["aderencia"][condicao] > melhor["aderencia"][condicao]:
			melhor = p
	return melhor


## Atributos usados pela simulação. Efeitos "soma" são aplicados antes dos
## "mult", para que a ordem de instalação não altere o resultado.
func atributos_efetivos(condicao: String) -> Dictionary:
	var attrs := {}
	for a in ATRIBUTOS:
		attrs[a] = float(base[a])
	for op in OPS:
		for categoria in pecas:
			for efeito in pecas[categoria].get("efeitos", []):
				if efeito["op"] != op:
					continue
				if op == "soma":
					attrs[efeito["atributo"]] += float(efeito["valor"])
				else:
					attrs[efeito["atributo"]] *= float(efeito["valor"])
	var pneu := escolher_pneu(condicao)
	if pneu.is_empty():
		push_error("Carro %s sem pneu para correr" % id)
	else:
		attrs["aderencia"] *= float(pneu["aderencia"][condicao])
	attrs["tracao"] = base["tracao"]
	attrs["pneu"] = pneu.get("id", "")
	return attrs
