class_name Expedicao
extends RefCounted
## docs/mecanicas_para_godot.md #6 — modelo Melvor.

enum Estado { EM_CURSO, CONCLUIDA }

var regiao_id: String
var equipe: Array = []  # Array[String] ids de Orfao
var inicio_unix: int = 0
var duracao_seg: int = 0
var estado: Estado = Estado.EM_CURSO


func to_dict() -> Dictionary:
	return {
		"regiao_id": regiao_id,
		"equipe": equipe,
		"inicio_unix": inicio_unix,
		"duracao_seg": duracao_seg,
		"estado": estado,
	}


static func from_dict(d: Dictionary) -> Expedicao:
	var e := Expedicao.new()
	e.regiao_id = d.get("regiao_id", "")
	e.equipe = d.get("equipe", [])
	e.inicio_unix = d.get("inicio_unix", 0)
	e.duracao_seg = d.get("duracao_seg", 0)
	e.estado = d.get("estado", Estado.EM_CURSO) as Estado
	return e
