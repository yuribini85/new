class_name CarroSprite
extends Node2D
## Placeholder do sprite de carro: um retângulo desenhado em uma das 16
## direções, já projetado em isometria. A troca pelos sprites pré-renderizados
## mantém a interface: `direcao` (0..15) e `cor`.

const COMPRIMENTO_M := 4.5
const LARGURA_M := 1.8

var cor := Color.WHITE:
	set(v):
		cor = v
		queue_redraw()
var direcao := 0:
	set(v):
		if v != direcao:
			direcao = v
			queue_redraw()
## Pixels por metro (a mesma escala da pista).
var escala := 1.0:
	set(v):
		escala = v
		queue_redraw()


func _draw() -> void:
	var rumo := direcao * TAU / Iso.DIRECOES
	var frente := Vector2.from_angle(rumo) * COMPRIMENTO_M * 0.5
	var lado := Vector2.from_angle(rumo + PI / 2.0) * LARGURA_M * 0.5
	var corpo := PackedVector2Array([frente + lado, frente - lado, -frente - lado, -frente + lado])
	var vidro := PackedVector2Array([frente * 0.6 + lado * 0.8, frente * 0.6 - lado * 0.8, frente * 0.1 - lado * 0.8, frente * 0.1 + lado * 0.8])
	draw_colored_polygon(_projetar(corpo), cor)
	draw_colored_polygon(_projetar(vidro), cor.darkened(0.55))


func _projetar(pontos: PackedVector2Array) -> PackedVector2Array:
	var r := PackedVector2Array()
	for p in pontos:
		r.append(Iso.para_tela(p, escala))
	return r
