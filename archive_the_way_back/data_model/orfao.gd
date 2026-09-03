class_name Orfao
extends RefCounted
## Modelo de órfão. docs/mecanicas_para_godot.md #3.

enum Estado { CRIANCA, ADULTO_OCIOSO, ALOCADO, EM_EXPEDICAO, MORTO }

var id: String
var nome: String
var genero: String  # "masculino" | "feminino" — só para sorteio de nome
var aptidao: String  # campo|cozinha|agua|oficina|bracos|letras
var cicatriz_id: String = ""  # "" = sem cicatriz (35% dos casos)
var cicatriz_visivel: bool = false

var estado: Estado = Estado.CRIANCA
var local_id: String = ""  # id do edifício onde mora (Lar/Alojamento) ou trabalha
var nascido_em: int = 0  # unix timestamp de chegada à vila
var velocidade: float = 1.0  # 0.9-1.1, puramente visual


func to_dict() -> Dictionary:
	return {
		"id": id,
		"nome": nome,
		"genero": genero,
		"aptidao": aptidao,
		"cicatriz_id": cicatriz_id,
		"cicatriz_visivel": cicatriz_visivel,
		"estado": estado,
		"local_id": local_id,
		"nascido_em": nascido_em,
		"velocidade": velocidade,
	}


static func from_dict(d: Dictionary) -> Orfao:
	var o := Orfao.new()
	o.id = d.get("id", "")
	o.nome = d.get("nome", "")
	o.genero = d.get("genero", "masculino")
	o.aptidao = d.get("aptidao", "")
	o.cicatriz_id = d.get("cicatriz_id", "")
	o.cicatriz_visivel = d.get("cicatriz_visivel", false)
	o.estado = d.get("estado", Estado.CRIANCA) as Estado
	o.local_id = d.get("local_id", "")
	o.nascido_em = d.get("nascido_em", 0)
	o.velocidade = d.get("velocidade", 1.0)
	return o
