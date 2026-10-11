class_name HudArena
extends Control
## Painel da arena: uma linha por carro com o nome e o carro visto de cima em
## seis regiões (frente, lados, traseira; esquerda e direita), cada uma na cor
## do dano. Cores como o indicador do estudo: verde → amarelo até a metade,
## amarelo → vermelho até o limite da ré, piscando daí até quebrar; preto no
## eliminado. O número é o pior dano em %.

const LINHA := 46.0
const LARGURA := 250.0
const CARRO := Vector2(30.0, 40.0)  # o carro de pé: frente para cima
## Com muitos carros (lutas de 15), as linhas encolhem para caber na tela.
const MUITOS := 6
const ESCALA_COMPACTA := 0.62
const VERDE := Color(0.3, 0.8, 0.35)
const AMARELO := Color(0.95, 0.8, 0.2)
const VERMELHO := Color(0.92, 0.2, 0.15)
const ALERTA := Color(1.0, 0.95, 0.85)

## [{id, nome, cor, dano: PackedFloat32Array(6), eliminado, voce}]
var linhas: Array = []:
	set(v):
		linhas = v
		queue_redraw()
var limite_re := 0.9


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_d: float) -> void:
	if linhas.any(func(l): return not l["eliminado"] and _pior(l["dano"]) >= limite_re):
		queue_redraw()  # pisca


func _draw() -> void:
	var fonte := Tipografia.fonte("semibold")
	var k := ESCALA_COMPACTA if linhas.size() > MUITOS else 1.0
	var linha := LINHA * k
	var carro := CARRO * k
	var y := 0.0
	for l in linhas:
		var r := Rect2(0, y, LARGURA, linha - 6.0 * k)
		draw_rect(r, Color(0.05, 0.05, 0.06, 0.72))
		draw_rect(Rect2(r.position, Vector2(4, r.size.y)), l["cor"])
		_carro(Vector2(12, y + (r.size.y - carro.y) * 0.5), l["dano"], l["eliminado"], carro)
		var cor_nome := Aba.COR_DESTAQUE if l.get("voce", false) else Color(0.92, 0.92, 0.9)
		if l["eliminado"]:
			cor_nome = Color(0.55, 0.55, 0.55)
		draw_string(fonte, Vector2(20 + carro.x + 4, y + r.size.y * 0.5 + 7 * k), String(l["nome"]), HORIZONTAL_ALIGNMENT_LEFT,
				LARGURA - 128, roundi(20 * maxf(k, 0.8)), cor_nome)
		var txt := "FORA" if l["eliminado"] else "%d%%" % roundi(_pior(l["dano"]) * 100.0)
		draw_string(Tipografia.fonte_numero(), Vector2(LARGURA - 72, y + r.size.y * 0.5 + 8 * k), txt,
				HORIZONTAL_ALIGNMENT_RIGHT, 62, roundi(19 * maxf(k, 0.8)), Color(0.75, 0.75, 0.75) if l["eliminado"] else Color.WHITE)
		y += linha
	custom_minimum_size = Vector2(LARGURA, y)


## Carro de pé em 2 colunas × 3 linhas: [frente_e, frente_d], [lado_e, lado_d], [tras_e, tras_d].
func _carro(o: Vector2, dano: PackedFloat32Array, eliminado: bool, tam := CARRO) -> void:
	var cel := Vector2(tam.x / 2.0, tam.y / 3.0)
	for r in 6:
		var col := r % 2
		var lin := r / 2
		var q := Rect2(o + Vector2(col * cel.x, lin * cel.y), cel - Vector2(2, 2))
		draw_rect(q, Color(0.02, 0.02, 0.02) if eliminado else cor(dano[r], limite_re))


func cor(d: float, re: float) -> Color:
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
