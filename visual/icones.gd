class_name Icones
extends RefCounted
## Placeholders 2D das listas: silhueta lateral do carro e traçado da pista.
## Desenhados no Control, sem imagem; a troca por arte mantém as chamadas.


static func carro(categoria: String, cor: Color, tamanho := Vector2(124, 60)) -> Control:
	var c := Control.new()
	c.custom_minimum_size = tamanho
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): _desenhar_carro(c, categoria, cor))
	return c


static func pista(p: Pista) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(96, 72)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pts := p.pontos(10.0)
	c.draw.connect(func(): _desenhar_pista(c, pts))
	return c


static func _desenhar_carro(c: Control, categoria: String, cor: Color) -> void:
	var f: Dictionary = CarroBloco.FORMAS.get(categoria, CarroBloco.FORMAS["seda"])
	var esc := (c.size.x - 8.0) / 4.8  # px por metro, o maior carro cabe
	var comp: float = f["c"] * esc
	var x0 := (c.size.x - comp) * 0.5
	var chao := c.size.y - 6.0
	var r := CarroBloco.RAIO_RODA * esc
	var h: float = f["h"] * esc
	var base := chao - r * 0.9
	c.draw_rect(Rect2(x0, base - h, comp, h), cor)
	var cab_c: float = comp * f["cab"]
	var hc: float = f["hc"] * esc
	var cx: float = x0 + comp * 0.5 + comp * f["recuo"] - cab_c * 0.5
	var topo := base - h - hc
	var cabine := PackedVector2Array([
		Vector2(cx - cab_c * 0.18, base - h), Vector2(cx + cab_c * 0.12, topo),
		Vector2(cx + cab_c * 0.85, topo), Vector2(cx + cab_c * 1.12, base - h)])
	c.draw_colored_polygon(cabine, cor.darkened(0.6) if f["teto"] else Color(0.15, 0.15, 0.17))
	for k in [-1.0, 1.0]:
		var centro := Vector2(x0 + comp * 0.5 + k * comp * 0.32, chao - r)
		c.draw_circle(centro, r, Color(0.08, 0.08, 0.09))
		c.draw_circle(centro, r * 0.45, Color(0.6, 0.6, 0.62))


static func _desenhar_pista(c: Control, pts: PackedVector2Array) -> void:
	var caixa := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		caixa = caixa.expand(p)
	var margem := 6.0
	var esc := minf((c.size.x - 2 * margem) / maxf(caixa.size.x, 1.0), (c.size.y - 2 * margem) / maxf(caixa.size.y, 1.0))
	var centro := c.size * 0.5
	var linha := PackedVector2Array()
	for p in pts:
		# y da pista cresce para cima (rumo anti-horário); na tela, para baixo.
		var q := (p - caixa.get_center()) * esc
		linha.append(centro + Vector2(q.x, -q.y))
	c.draw_polyline(linha, Color(0.85, 0.85, 0.85), 5.0, true)
	c.draw_polyline(linha, Color(0.32, 0.33, 0.36), 3.0, true)
	c.draw_circle(linha[0], 3.5, Color(1.0, 0.82, 0.1))
