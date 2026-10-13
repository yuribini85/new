class_name PainelVidaArena
extends Control
## Integridade dos carros da sua equipe na luta, embaixo da tela e em escala
## grande: o carro visto de cima em seis regiões (frente, lados, traseira;
## esquerda e direita), cada uma na cor do dano, com o piloto e o modelo. Cores
## como o indicador do estudo: verde → amarelo até a metade, amarelo →
## vermelho até o limite da ré, piscando daí até quebrar; preto no eliminado.
## A barra embaixo do nome enche de vermelho com o pior dano.

const CARRO := Vector2(64.0, 92.0)  # o carro de pé: frente para cima
const CARTAO := Vector2(240.0, 116.0)
const SEPARACAO := 12.0
const VERDE := Color(0.3, 0.8, 0.35)
const AMARELO := Color(0.95, 0.8, 0.2)
const VERMELHO := Color(0.92, 0.2, 0.15)
const ALERTA := Color(1.0, 0.95, 0.85)
const FUNDO := Color(0.05, 0.05, 0.06, 0.82)

## [{nome, carro, cor, dano: PackedFloat32Array(6), eliminado}] (até dois).
var carros: Array = []:
	set(v):
		carros = v
		custom_minimum_size = Vector2(maxi(carros.size(), 1) * (CARTAO.x + SEPARACAO) - SEPARACAO, CARTAO.y)
		size = custom_minimum_size
		queue_redraw()
var limite_re := 0.9


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if carros.any(func(c): return not c["eliminado"] and _pior(c["dano"]) >= limite_re):
		queue_redraw()  # pisca


func _draw() -> void:
	var x := 0.0
	for c in carros:
		_cartao(c, Vector2(x, 0))
		x += CARTAO.x + SEPARACAO


func _cartao(c: Dictionary, o: Vector2) -> void:
	var r := Rect2(o, CARTAO)
	draw_rect(r, FUNDO)
	draw_rect(Rect2(o, Vector2(6, CARTAO.y)), c["cor"])
	var pc := o + Vector2(16, (CARTAO.y - CARRO.y) * 0.5)
	_carro(pc, c["dano"], c["eliminado"])
	var x := pc.x + CARRO.x + 14
	var largura := o.x + CARTAO.x - x - 10
	var fonte := Tipografia.fonte("semibold")
	draw_string(fonte, Vector2(x, o.y + 38), String(c["nome"]), HORIZONTAL_ALIGNMENT_LEFT, largura, 21,
			Color(0.5, 0.5, 0.52) if c["eliminado"] else Aba.COR_DESTAQUE)
	draw_string(Tipografia.fonte("regular"), Vector2(x, o.y + 66), String(c.get("carro", "")),
			HORIZONTAL_ALIGNMENT_LEFT, largura, 18, Color(0.66, 0.66, 0.68))
	# Pior dano: barra cheia = eliminado.
	var barra := Rect2(Vector2(x, o.y + 82), Vector2(largura, 12))
	draw_rect(barra, Color(1, 1, 1, 0.12))
	var cheio := 1.0 if c["eliminado"] else clampf(_pior(c["dano"]), 0.0, 1.0)
	draw_rect(Rect2(barra.position, Vector2(barra.size.x * cheio, barra.size.y)),
			Aba.COR_RUIM.darkened(0.3) if c["eliminado"] else cor(cheio, limite_re))
	if c["eliminado"]:
		draw_string(fonte, Vector2(x, o.y + 112), "FORA", HORIZONTAL_ALIGNMENT_LEFT, largura, 18, Aba.COR_RUIM)


## Carro de pé em 2 colunas × 3 linhas: [frente_e, frente_d], [lado_e, lado_d], [tras_e, tras_d].
func _carro(o: Vector2, dano: PackedFloat32Array, eliminado: bool) -> void:
	var cel := Vector2(CARRO.x / 2.0, CARRO.y / 3.0)
	for r in 6:
		var q := Rect2(o + Vector2((r % 2) * cel.x, (r / 2) * cel.y), cel - Vector2(3, 3))
		draw_rect(q, Color(0.02, 0.02, 0.02) if eliminado else cor(dano[r], limite_re))


static func cor(d: float, re: float) -> Color:
	if d <= 0.5:
		return VERDE.lerp(AMARELO, d / 0.5)
	if d < re:
		return AMARELO.lerp(VERMELHO, (d - 0.5) / maxf(re - 0.5, 0.01))
	# Perto de quebrar: alterna vermelho e claro, mais rápido quanto pior.
	var hz := lerpf(2.0, 6.0, clampf((d - re) / maxf(1.0 - re, 0.01), 0.0, 1.0))
	return VERMELHO if fmod(Time.get_ticks_msec() / 1000.0 * hz, 1.0) < 0.5 else ALERTA


static func _pior(d: PackedFloat32Array) -> float:
	var m := 0.0
	for x in d:
		m = maxf(m, x)
	return m
