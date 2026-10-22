class_name CartaoGestos
extends ColorRect
## COMO PILOTAR (decisão 131, R5): os três gestos da corrida, cada um com a
## animação dele e duas linhas, antes da primeira corrida pilotada (a largada
## espera no grid) e depois pelo •••. Na pista, só o aviso curto e as deixas
## pintadas; a explicação fica aqui, nunca no meio da corrida.

signal fechado

const GESTOS := [
	["curva", "SEGURE NA FAIXA VERDE", "Encoste quando o carro chegar nela e solte na faixa da saída da curva."],
	["deslize", "DESLIZE PARA AS SETAS", "Fecha a porta de quem vem atrás e passa no vácuo de quem vai à frente."],
	["largada", "TOQUE QUANDO APAGAR", "As três luzes vermelhas da largada: o toque na hora larga melhor."],
]


func _init() -> void:
	color = Color(0, 0, 0, 0.7)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var caixa := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Aba.COR_CARTAO, 0.97)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	caixa.add_theme_stylebox_override("panel", sb)
	caixa.custom_minimum_size = Vector2(640, 0)
	centro.add_child(caixa)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	caixa.add_child(v)
	var titulo := Label.new()
	titulo.text = "COMO PILOTAR"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tipografia.rotulo(titulo, "semibold", Aba.FONTE_TITULO)
	titulo.add_theme_color_override("font_color", Aba.COR_DESTAQUE)
	v.add_child(titulo)
	for g in GESTOS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		v.add_child(h)
		var desenho := GestoAnimado.new()
		desenho.gesto = g[0]
		h.add_child(desenho)
		var textos := VBoxContainer.new()
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		textos.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(textos)
		var nome := Label.new()
		nome.text = g[1]
		Tipografia.rotulo(nome, "semibold", 28)
		textos.add_child(nome)
		var sub := Label.new()
		sub.text = g[2]
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(380, 0)
		sub.add_theme_font_size_override("font_size", Aba.FONTE_PEQUENA)
		sub.add_theme_color_override("font_color", Aba.COR_SECUNDARIA)
		textos.add_child(sub)
	var ok := Button.new()
	Tipografia.acao_primaria(ok, "ENTENDI", Aba.COR_DESTAQUE, Color(0.1, 0.1, 0.1), 28, Tipografia.ALTURA_SECUNDARIA)
	ok.pressed.connect(fechar)
	v.add_child(ok)


func fechar() -> void:
	fechado.emit()
	queue_free()


## A animação de um gesto em laço: o carro visto de cima numa faixa de pista,
## a deixa (faixa verde, setas ou luzes) e o dedo.
class GestoAnimado:
	extends Control
	const TAM := Vector2(150, 150)
	const CICLO_S := 3.0
	const COR_PISTA := Color(0.17, 0.17, 0.19)
	const COR_VERDE := Color(0.36, 0.82, 0.47)
	const COR_SETA := Color(1.0, 0.85, 0.2)
	const COR_CARRO := Color(0.2, 0.55, 0.35)
	const COR_RIVAL := Color(0.75, 0.3, 0.25)
	var gesto := "curva"
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = TAM
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t = fposmod(_t + delta, CICLO_S)
		queue_redraw()

	func _draw() -> void:
		var u := _t / CICLO_S
		draw_rect(Rect2(Vector2.ZERO, TAM), Color(0.08, 0.09, 0.1), true)
		var pista := Rect2(TAM.x * 0.25, 0, TAM.x * 0.5, TAM.y)
		draw_rect(pista, COR_PISTA, true)
		var carro := Rect2(TAM.x * 0.5 - 12, TAM.y * 0.62, 24, 38)
		match gesto:
			"curva":
				# A faixa da freada desce até o carro (o dedo encosta); depois a
				# da saída (o dedo solta).
				var y1 := lerpf(-30.0, TAM.y + 30.0, u * 1.6)
				var y2 := lerpf(-30.0, TAM.y + 30.0, u * 1.6 - 0.75)
				for y in [y1, y2]:
					draw_rect(Rect2(pista.position.x, y - 12.0, pista.size.x, 24.0), Color(COR_VERDE, 0.55), true)
				_carro(carro, COR_CARRO)
				var dentro := y1 >= carro.position.y and y2 < carro.position.y + 10.0
				_dedo(Vector2(TAM.x * 0.5, TAM.y * 0.3), dentro)
			"deslize":
				var lado := -1.0 if int(_t / CICLO_S * 2.0) % 2 == 0 else 1.0
				_carro(Rect2(carro.position + Vector2(0, -50), carro.size), COR_CARRO)
				_carro(Rect2(carro.position + Vector2(lado * 16.0, 18), carro.size), COR_RIVAL)
				var fase := fposmod(u * 2.0, 1.0)
				for k in 3:
					var x := TAM.x * 0.5 + lado * (26.0 + k * 12.0)
					var cy := TAM.y * 0.35
					var a := 1.0 - absf(fase - k / 3.0)
					var pts := PackedVector2Array([Vector2(x, cy - 10), Vector2(x + lado * 10.0, cy), Vector2(x, cy + 10)])
					draw_polyline(pts, Color(COR_SETA, clampf(a, 0.3, 1.0)), 4.0)
				_dedo(Vector2(TAM.x * 0.5 + lado * lerpf(0.0, 50.0, fase), TAM.y * 0.82), true)
			"largada":
				var apagou := u > 0.55
				for k in 3:
					var c := Vector2(TAM.x * 0.3 + k * TAM.x * 0.2, TAM.y * 0.25)
					draw_circle(c, 14.0, Color(0.15, 0.05, 0.05) if apagou else Color(1.0, 0.2, 0.15))
				_carro(carro, COR_CARRO)
				_dedo(Vector2(TAM.x * 0.5, TAM.y * 0.5), apagou and u < 0.75)

	func _carro(r: Rect2, cor: Color) -> void:
		draw_rect(r, cor, true)
		draw_rect(Rect2(r.position + Vector2(4, 8), Vector2(r.size.x - 8, 12)), Color(0.05, 0.05, 0.05), true)

	## O dedo: anel vazio no ar, cheio encostado.
	func _dedo(p: Vector2, encostado: bool) -> void:
		if encostado:
			draw_circle(p, 16.0, Color(1, 1, 1, 0.85))
		else:
			draw_arc(p, 16.0, 0.0, TAU, 32, Color(1, 1, 1, 0.6), 3.0)
