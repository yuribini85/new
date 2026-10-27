class_name AndarIdle
extends Control
## Um andar do complexo da equipe (docs/idle/direcao.md, 4): a estação de uma
## melhoria, desenhada em planos facetados como a arte dos personagens. O chefe
## do acervo fica à esquerda; à direita a placa (estação e nível), o efeito, a
## chegada prevista e os botões +1 / +10 / MÁX. A estação muda de fase nos
## níveis FASES: mais luz, mais mecânicos, estandarte e placa dourada.

signal comprar(quantos: int)  # 1, 10 ou -1 (MÁX.)

## Apresentação, não balanceamento.
const ALTURA := 300.0
const FASES := [10, 25, 50]
const PAREDE := Color("141a23")
const PAREDE_ESCURA := Color("10151c")
const PISO := Color("0b0e13")
const LUZ := Color(1.0, 0.77, 0.24)
const VERMELHO := Color("e5484d")

var id: String
var tipo: String  # o efeito da melhoria: desenha os objetos da estação
var fase := 0
var nome: Label
var nivel: Label
var efeito: Label
var previsao: Label
var botao: Button
var dez: Button
var maximo: Button
var _chefe: TextureRect


func _init(m: Dictionary) -> void:
	id = String(m["id"])
	tipo = String(m["efeito"])
	custom_minimum_size = Vector2(0, ALTURA)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_chefe = TextureRect.new()
	var caminho := "res://arte/personagens/corpo/%s.webp" % String(m.get("chefe", ""))
	_chefe.texture = load(caminho) if ResourceLoader.exists(caminho) else null
	_chefe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chefe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # escala uniforme
	_chefe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Corpo inteiro maior que o andar: o piso corta as pernas, como no corte do prédio.
	_chefe.position = Vector2(-20, 6)
	_chefe.size = Vector2(270, 560)
	add_child(_chefe)
	var lado := VBoxContainer.new()
	lado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lado.offset_left = 230
	lado.offset_right = -14
	lado.offset_top = 12
	lado.offset_bottom = -14
	lado.add_theme_constant_override("separation", 4)
	add_child(lado)
	var placa := HBoxContainer.new()
	placa.add_theme_constant_override("separation", 10)
	lado.add_child(placa)
	nome = IdleUI.rotulo(String(m.get("estacao", m["nome"])).to_upper(), 20, IdleUI.COR_CROMO, placa)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	nivel = IdleUI.rotulo("", 20, IdleUI.COR_OURO_CLARO, placa)
	efeito = IdleUI.rotulo("", 22, IdleUI.COR_GANHO, lado)
	efeito.clip_text = true
	previsao = IdleUI.rotulo("", 18, IdleUI.COR_SECUNDARIA, lado)
	previsao.clip_text = true
	var vao := Control.new()
	vao.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lado.add_child(vao)
	var trio := HBoxContainer.new()
	trio.add_theme_constant_override("separation", 8)
	lado.add_child(trio)
	botao = _botao(trio, 1)
	dez = _botao(trio, 10)
	maximo = _botao(trio, -1)


func _botao(pai: Control, quantos: int) -> Button:
	var b := IdleUI.botao("", IdleUI.COR_OURO, 18, 96, pai)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): comprar.emit(quantos))
	return b


## A fase da estação pelo nível (0 antes do primeiro marco).
static func fase_do_nivel(n: int) -> int:
	var f := 0
	for m in FASES:
		if n >= m:
			f += 1
	return f


func _draw() -> void:
	var w := size.x
	var h := size.y
	var piso_y := h - 46.0
	# Parede em planos e o piso.
	draw_rect(Rect2(0, 0, w, h), PAREDE)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.42, 0), Vector2(w * 0.3, piso_y),
			Vector2(0, piso_y)]), PAREDE_ESCURA)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.72, 0), Vector2(w, 0), Vector2(w, piso_y),
			Vector2(w * 0.8, piso_y)]), PAREDE_ESCURA.lerp(PAREDE, 0.5))
	# Luz do teto: cone em dois tons (mais lâmpadas nas fases).
	for k in 1 + mini(fase, 2):
		var cx := w * (0.62 + 0.18 * k) if k > 0 else w * 0.55
		var abertura := 120.0 + 30.0 * fase
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 14, 0), Vector2(cx + 14, 0),
				Vector2(cx + abertura, piso_y), Vector2(cx - abertura, piso_y)]), Color(LUZ, 0.07))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 8, 0), Vector2(cx + 8, 0),
				Vector2(cx + abertura * 0.55, piso_y), Vector2(cx - abertura * 0.55, piso_y)]), Color(LUZ, 0.08))
		draw_rect(Rect2(cx - 16, 0, 32, 6), Color(LUZ, 0.9))
	draw_rect(Rect2(0, piso_y, w, h - piso_y), PISO)
	draw_line(Vector2(0, piso_y), Vector2(w, piso_y), Color("2b3340"), 2.0)
	_objetos(w, piso_y)
	# Mecânicos a mais (um por fase), em silhueta ao fundo.
	for k in fase:
		_silhueta(Vector2(w * (0.5 + 0.13 * k), piso_y))
	# Estandarte vermelho (fase 2) e placa dourada (fase 3).
	if fase >= 2:
		var bx := w - 40.0
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 18, 0), Vector2(bx + 18, 0), Vector2(bx + 18, 74),
				Vector2(bx, 62), Vector2(bx - 18, 74)]), VERMELHO)
	if fase >= 3:
		draw_rect(Rect2(w * 0.36, 4, 64, 10), Color("ffc53d"))
	draw_line(Vector2(0, 0), Vector2(w, 0), Color("232b37"), 2.0)


## Os objetos da estação, em polígonos chapados com aresta de luz.
func _objetos(w: float, piso: float) -> void:
	var base := w * 0.62
	var escuro := Color("2a313c")
	var claro := Color("5b6472")
	match tipo:
		"potencia":
			# Bancada com um motor em cima.
			draw_colored_polygon(PackedVector2Array([Vector2(base - 90, piso - 46), Vector2(base + 110, piso - 52),
					Vector2(base + 110, piso), Vector2(base - 90, piso)]), Color("2a2118"))
			draw_colored_polygon(PackedVector2Array([Vector2(base - 30, piso - 96), Vector2(base + 10, piso - 112),
					Vector2(base + 60, piso - 100), Vector2(base + 70, piso - 62), Vector2(base - 34, piso - 54)]), claro)
			draw_line(Vector2(base + 10, piso - 112), Vector2(base + 60, piso - 100), LUZ, 2.0)
		"aderencia":
			# Pilhas de pneus.
			for k in 3:
				var x := base - 80 + k * 64
				for j in 3 - (k % 2):
					var y := piso - 22 - j * 24
					draw_rect(Rect2(x, y, 52, 20), Color("16181c"))
					draw_rect(Rect2(x + 10, y + 6, 32, 8), Color("2c3036"))
		"agressividade":
			# Cockpit do simulador com tela.
			draw_rect(Rect2(base - 60, piso - 150, 150, 84), Color("0a1a22"))
			draw_rect(Rect2(base - 54, piso - 144, 138, 72), Color("1f6f8b").darkened(0.35))
			draw_colored_polygon(PackedVector2Array([Vector2(base - 40, piso), Vector2(base - 20, piso - 50),
					Vector2(base + 50, piso - 56), Vector2(base + 70, piso)]), escuro)
		"vacuo":
			# Túnel de vento: anel e hélice.
			draw_arc(Vector2(base + 20, piso - 90), 70, 0, TAU, 9, claro, 10.0)
			for k in 3:
				var a := TAU * k / 3.0
				draw_line(Vector2(base + 20, piso - 90), Vector2(base + 20, piso - 90) + Vector2(cos(a), sin(a)) * 56,
						escuro, 14.0)
		"renda":
			if id == "arquibancada":
				# Degraus da arquibancada com torcida em pontos.
				for k in 4:
					var y := piso - 18 - k * 26
					draw_rect(Rect2(base - 100 + k * 16, y, 240 - k * 32, 18), escuro.lerp(claro, k * 0.2))
					for j in 6:
						draw_circle(Vector2(base - 84 + k * 16 + j * 34, y - 8), 7, [VERMELHO, Color("ffc53d"), Color("c9ced6")][(j + k) % 3])
			else:
				# Mesa e painel de patrocinadores.
				draw_rect(Rect2(base - 80, piso - 150, 210, 70), Color("1b2230"))
				for k in 4:
					draw_rect(Rect2(base - 70 + k * 50, piso - 140, 40, 22), [Color("ffc53d"), VERMELHO, Color("c9ced6"), Color("6fd08c")][k])
				draw_colored_polygon(PackedVector2Array([Vector2(base - 60, piso - 44), Vector2(base + 120, piso - 50),
						Vector2(base + 120, piso), Vector2(base - 60, piso)]), Color("2a2118"))


func _silhueta(pe: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([pe + Vector2(-12, 0), pe + Vector2(-9, -40), pe + Vector2(-14, -70),
			pe + Vector2(-5, -82), pe + Vector2(5, -82), pe + Vector2(14, -70), pe + Vector2(9, -40),
			pe + Vector2(12, 0)]), Color("0a0d12"))
	draw_circle(pe + Vector2(0, -92), 10, Color("0a0d12"))
