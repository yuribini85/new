class_name Arvore
extends RefCounted
## docs/mecanicas_para_godot.md #5.

enum Estado { DE_PE, TOCO }

var celula: Vector2i
var offset: Vector2
var estado: Estado = Estado.DE_PE
var variante: int = 0


func to_dict() -> Dictionary:
	return {
		"celula": [celula.x, celula.y],
		"offset": [offset.x, offset.y],
		"estado": estado,
		"variante": variante,
	}


static func from_dict(d: Dictionary) -> Arvore:
	var a := Arvore.new()
	var c: Array = d.get("celula", [0, 0])
	a.celula = Vector2i(c[0], c[1])
	var o: Array = d.get("offset", [0, 0])
	a.offset = Vector2(o[0], o[1])
	a.estado = d.get("estado", Estado.DE_PE) as Estado
	a.variante = d.get("variante", 0)
	return a
