class_name EfeitosIdle
extends Control
## Números que pipocam e faíscas por cima da tela do The Fastfather
## (docs/idle/comparacao_white_foot.md, item 4: "a compra tem peso"). Uma camada
## só, que não pega toque: `faiscas` estoura losangos dourados de um ponto e
## `pipoca` faz um número nascer grande, quicar, tremer e subir sumindo. Com
## "Reduzir animações" não desenha nada (o número do topo já mostra o valor).

## Apresentação, não balanceamento.
const GRAVIDADE := 700.0
const SUBIDA := 90.0
const VIDA_NUMERO_S := 1.1
const MAX_FAISCAS := 160
const NOTA := Color("9fae86")  # verde-acinzentado das notas de dólar da época

var _faiscas: Array = []
var _numeros: Array = []
var _notas: Array = []  # notas de dólar voando até o dinheiro do alto
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_rng.randomize()


func _agora() -> float:
	return Time.get_ticks_msec() / 1000.0


## Faíscas que estouram de `onde` (coordenadas globais).
func faiscas(onde: Vector2, cor: Color = IdleUI.COR_OURO_CLARO, n := 22) -> void:
	if Preferencias.reduzir_animacoes:
		return
	var p := onde - get_global_rect().position
	for i in n:
		var a := _rng.randf() * TAU
		var v := _rng.randf_range(220.0, 620.0)
		_faiscas.append({"p": p, "v": Vector2(cos(a), sin(a)) * v + Vector2(0, -180), "t0": _agora(),
				"vida": _rng.randf_range(0.45, 0.85), "cor": cor.lerp(Color.WHITE, _rng.randf() * 0.4),
				"r": _rng.randf_range(4.0, 9.0)})
	while _faiscas.size() > MAX_FAISCAS:
		_faiscas.pop_front()
	queue_redraw()


## Um número que pipoca em `onde` (global): nasce `1 + impacto` vezes maior,
## encolhe com um quique, treme no começo e sobe sumindo.
func pipoca(onde: Vector2, texto: String, cor: Color = IdleUI.COR_DINHEIRO, tamanho := 40, impacto := 0.6) -> void:
	if Preferencias.reduzir_animacoes:
		return
	_numeros.append({"p": onde - get_global_rect().position, "t0": _agora(), "texto": texto, "cor": cor,
			"tam": IdleUI.legivel(tamanho), "impacto": impacto})
	queue_redraw()


## O prêmio em notas de dólar: `n` notas saem de `de` e voam em curva até
## `para` (globais), girando e balançando, umas depois das outras.
func notas(de: Vector2, para: Vector2, n := 8) -> void:
	if Preferencias.reduzir_animacoes:
		return
	var o := get_global_rect().position
	for i in n:
		var meio := (de + para) * 0.5 + Vector2(_rng.randf_range(-260.0, 260.0), _rng.randf_range(-160.0, 40.0))
		_notas.append({"a": de - o + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-20, 20)), "b": meio - o,
				"c": para - o, "t0": _agora() + i * 0.06, "vida": _rng.randf_range(0.7, 0.95),
				"giro": _rng.randf_range(-6.0, 6.0), "fase": _rng.randf() * TAU})
	queue_redraw()


func _process(_delta: float) -> void:
	if not _faiscas.is_empty() or not _numeros.is_empty() or not _notas.is_empty():
		queue_redraw()


func _draw() -> void:
	var t := _agora()
	var vivas := []
	for s in _faiscas:
		var k := (t - float(s["t0"])) / float(s["vida"])
		if k >= 1.0:
			continue
		vivas.append(s)
		var dt := t - float(s["t0"])
		var p: Vector2 = s["p"] + s["v"] * dt + Vector2(0, GRAVIDADE) * dt * dt * 0.5
		var r := float(s["r"]) * (1.0 - k * 0.6)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.6, 0), p + Vector2(0, r),
				p + Vector2(-r * 0.6, 0)]), Color(s["cor"], 1.0 - k))
	_faiscas = vivas
	var fonte := Tipografia.fonte("deco")  # dinheiro em letreiro art déco
	var vivos := []
	for q in _numeros:
		var k := (t - float(q["t0"])) / VIDA_NUMERO_S
		if k >= 1.0:
			continue
		vivos.append(q)
		# Nasce grande e encolhe com um quique; treme só no começo.
		var e := clampf(k * 6.0, 0.0, 1.0)
		var imp := float(q["impacto"])
		var tam := int(float(q["tam"]) * (1.0 + imp * (1.0 - e) * (1.0 - e)) * (1.0 + 0.08 * sin(e * PI)))
		var tremor := Vector2(sin(k * 90.0), cos(k * 77.0)) * 3.0 * imp * (1.0 - e)
		var w := fonte.get_string_size(q["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var p: Vector2 = q["p"] + tremor - Vector2(w * 0.5, SUBIDA * k)
		var a := 1.0 - smoothstep(0.65, 1.0, k)
		draw_string(fonte, p + Vector2(2, 3), q["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, 0.6 * a))
		draw_string(fonte, p, q["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(q["cor"], a))
	_numeros = vivos
	var voando := []
	for q in _notas:
		var k := (t - float(q["t0"])) / float(q["vida"])
		if k >= 1.0:
			continue
		voando.append(q)
		if k < 0.0:
			continue
		var e := k * k * (3.0 - 2.0 * k)
		var p: Vector2 = (q["a"] as Vector2).lerp(q["b"], e).lerp((q["b"] as Vector2).lerp(q["c"], e), e)
		var ang := float(q["giro"]) * k + sin(t * 9.0 + float(q["fase"])) * 0.4
		var esc := 1.0 - 0.45 * e
		draw_set_transform(p, ang, Vector2(esc, esc * (0.75 + 0.25 * cos(t * 11.0 + float(q["fase"])))))
		draw_rect(Rect2(-26, -12, 52, 24), NOTA)
		draw_rect(Rect2(-26, -12, 52, 24), NOTA.darkened(0.45), false, 2.0)
		draw_circle(Vector2.ZERO, 7.0, NOTA.lightened(0.25))
		draw_string(fonte, Vector2(-5, 6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, NOTA.darkened(0.55))
		draw_set_transform(Vector2.ZERO)
	_notas = voando
