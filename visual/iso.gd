class_name Iso
extends RefCounted
## Projeção isométrica 2:1 do plano da pista (metros) para a tela (pixels).

const DIRECOES := 16


static func para_tela(p: Vector2, escala: float) -> Vector2:
	return Vector2(p.x - p.y, (p.x + p.y) * 0.5) * escala


## Índice 0..15 do sprite pré-renderizado para um rumo no plano da pista.
## 0 = rumo 0 (+x); cresce no sentido anti-horário, como o rumo.
static func direcao(rumo: float) -> int:
	return posmod(roundi(rumo / TAU * DIRECOES), DIRECOES)
