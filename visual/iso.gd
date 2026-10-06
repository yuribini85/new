class_name Iso
extends RefCounted
## Projeção do plano da pista (metros) para a tela (pixels) na vista normal da
## Corrida3D: de cima, girada 45° (câmera vinda de +x/−y do plano). O minimapa
## usa a mesma, para não sair espelhado nem girado em relação à pista.

const DIRECOES := 16


static func para_tela(p: Vector2, escala: float) -> Vector2:
	return Vector2(p.x + p.y, p.x - p.y) * escala


## Índice 0..15 do sprite pré-renderizado para um rumo no plano da pista.
## 0 = rumo 0 (+x); cresce no sentido anti-horário, como o rumo.
static func direcao(rumo: float) -> int:
	return posmod(roundi(rumo / TAU * DIRECOES), DIRECOES)
