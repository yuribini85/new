class_name Iso
extends RefCounted
## Projeção isométrica 2:1. especificacao_tecnica_v1.md #10: tile 256×128 px.

static func cell_to_pos(cell: Vector2i, tile: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * tile.x / 2.0,
		(cell.x + cell.y) * tile.y / 2.0
	)
