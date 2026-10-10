extends SceneTree
## Gera o kit PROVISÓRIO das pistas (docs/arte_pistas.md) em res://arte/pistas/kit/:
## texturas repetíveis (sem emenda) e objetos vistos de cima, com fundo
## transparente e sem sombra. Ruído e formas simples, só para a montagem
## funcionar e as regras serem ajustadas; a arte final substitui arquivo por
## arquivo, com o mesmo nome e tamanho.
## Uso: godot --headless --path . --script res://tools/gerar_kit_pista.gd

const PASTA := "res://arte/pistas/kit/"
## Escala do kit: 32 px por metro (texturas de 512 px = 16 m).
const PX_M := 32

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	_rng.seed = 7
	# Texturas repetíveis: cor base, variação e grão.
	_textura("asfalto", Color(0.25, 0.25, 0.27), 0.05, 0.08, 6.0)
	_textura("grama_a", Color(0.29, 0.39, 0.25), 0.10, 0.10, 3.0)
	_textura("grama_b", Color(0.24, 0.33, 0.22), 0.12, 0.10, 2.0)
	_textura("mata", Color(0.11, 0.16, 0.12), 0.10, 0.06, 1.5)
	_textura("areia", Color(0.62, 0.53, 0.40), 0.08, 0.10, 4.0)
	_textura("brita", Color(0.56, 0.53, 0.48), 0.06, 0.25, 12.0)
	_textura("concreto", Color(0.38, 0.38, 0.40), 0.04, 0.06, 5.0)
	_textura("escape", Color(0.36, 0.47, 0.36), 0.05, 0.06, 4.0)
	_textura("agua", Color(0.13, 0.20, 0.24), 0.06, 0.03, 1.5)
	_zebra()
	# Objetos vistos de cima.
	for k in 6:
		_copa("arvore_%d" % (k + 1), 4.0 + k * 1.2, Color(0.13, 0.22, 0.14).lerp(Color(0.2, 0.28, 0.16), k / 5.0), 5 + k)
	for k in 3:
		_copa("pinheiro_%d" % (k + 1), 3.0 + k, Color(0.10, 0.18, 0.15), 9)
	for k in 3:
		_rocha("rocha_%d" % (k + 1), 2.5 + k * 1.5)
	_retangulo("box_modulo", Vector2(10, 8), Color(0.80, 0.80, 0.82), [[Rect2(0.5, 6.6, 9, 1.2), Color(1.0, 0.72, 0.35)]])
	_retangulo("arquibancada_modulo", Vector2(12, 10), Color(0.45, 0.47, 0.52),
			[[Rect2(0, 0, 12, 3), Color(0.82, 0.83, 0.86)], [Rect2(0, 3.5, 12, 0.4), Color(0.3, 0.32, 0.36)],
			[Rect2(0, 5.5, 12, 0.4), Color(0.3, 0.32, 0.36)], [Rect2(0, 7.5, 12, 0.4), Color(0.3, 0.32, 0.36)]])
	_retangulo("torre", Vector2(7, 7), Color(0.70, 0.71, 0.74), [[Rect2(1, 1, 5, 5), Color(0.55, 0.56, 0.6)]])
	_retangulo("portico", Vector2(2, 16), Color(0.30, 0.31, 0.34), [[Rect2(0.5, 0, 1, 16), Color(0.85, 0.85, 0.87)]])
	_retangulo("caminhao_1", Vector2(2.6, 14), Color(0.86, 0.86, 0.88), [[Rect2(0, 0, 2.6, 2.4), Color(0.75, 0.2, 0.15)]])
	_retangulo("caminhao_2", Vector2(2.6, 12), Color(0.80, 0.81, 0.84), [[Rect2(0, 0, 2.6, 2.4), Color(0.2, 0.3, 0.6)]])
	_retangulo("caminhao_3", Vector2(2.6, 10), Color(0.92, 0.92, 0.93), [[Rect2(0, 0, 2.6, 2.4), Color(0.3, 0.3, 0.32)]])
	_retangulo("tenda_1", Vector2(8, 6), Color(0.90, 0.90, 0.92), [[Rect2(0, 2.8, 8, 0.4), Color(0.75, 0.75, 0.78)]])
	_retangulo("tenda_2", Vector2(6, 6), Color(0.88, 0.88, 0.90), [[Rect2(2.8, 0, 0.4, 6), Color(0.74, 0.74, 0.77)]])
	_retangulo("conteiner_1", Vector2(2.5, 12), Color(0.70, 0.25, 0.18), [])
	_retangulo("conteiner_2", Vector2(2.5, 12), Color(0.20, 0.38, 0.55), [])
	_retangulo("conteiner_3", Vector2(2.5, 6), Color(0.78, 0.6, 0.2), [])
	_poste()
	print("kit gerado em ", PASTA)
	quit()


## Textura repetível: ruído que emenda (bordas periódicas) sobre a cor base.
func _textura(nome: String, cor: Color, variacao: float, grao: float, escala: float) -> void:
	var n := FastNoiseLite.new()
	n.seed = _rng.randi()
	n.frequency = escala / 512.0
	n.fractal_octaves = 4
	var img := n.get_seamless_image(512, 512, false, false, 0.15)
	img.convert(Image.FORMAT_RGBA8)
	var g := FastNoiseLite.new()
	g.seed = _rng.randi()
	g.frequency = 0.35
	var grao_img := g.get_seamless_image(512, 512, false, false, 0.1)
	for y in 512:
		for x in 512:
			var v := img.get_pixel(x, y).r - 0.5
			var gr := grao_img.get_pixel(x, y).r - 0.5
			var c := cor.lightened(v * variacao * 2.0) if v > 0.0 else cor.darkened(-v * variacao * 2.0)
			c = c.lightened(gr * grao) if gr > 0.0 else c.darkened(-gr * grao)
			c.a = 1.0
			img.set_pixel(x, y, c)
	img.save_png(PASTA + nome + ".png")


## Zebra: listras vermelhas e brancas de 1 m, repetível ao longo da pista
## (largura 1 m, comprimento 2 m).
func _zebra() -> void:
	var img := Image.create(PX_M, PX_M * 2, false, Image.FORMAT_RGBA8)
	for y in PX_M * 2:
		for x in PX_M:
			var c := Color(0.78, 0.16, 0.14) if y < PX_M else Color(0.92, 0.92, 0.9)
			img.set_pixel(x, y, c.darkened(_rng.randf() * 0.05))
	img.save_png(PASTA + "zebra.png")


## Copa de árvore vista de cima: bolhas sobrepostas com luz de cima e da esquerda.
func _copa(nome: String, raio_m: float, cor: Color, bolhas: int) -> void:
	var lado := int(ceil(raio_m * 2.4 * PX_M))
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c0 := Vector2(lado, lado) * 0.5
	for b in bolhas:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(0.0, raio_m * 0.45) * PX_M
		var centro := c0 + Vector2.from_angle(ang) * dist
		var r := _rng.randf_range(0.45, 0.65) * raio_m * PX_M
		for y in range(maxi(0, int(centro.y - r)), mini(lado, int(centro.y + r))):
			for x in range(maxi(0, int(centro.x - r)), mini(lado, int(centro.x + r))):
				var d := Vector2(x, y).distance_to(centro) / r
				if d > 1.0:
					continue
				# Luz de cima/esquerda: mais claro no quadrante superior esquerdo.
				var luz := clampf(0.5 - ((x - centro.x) + (y - centro.y)) / (2.0 * r), 0.0, 1.0)
				var cc := cor.lightened(luz * 0.25).darkened((1.0 - luz) * 0.2 + d * 0.15)
				cc.a = 1.0
				img.set_pixel(x, y, cc)
	img.save_png(PASTA + nome + ".png")


func _rocha(nome: String, raio_m: float) -> void:
	var lado := int(ceil(raio_m * 2.2 * PX_M))
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c0 := Vector2(lado, lado) * 0.5
	var pontos := PackedVector2Array()
	for k in 7:
		pontos.append(c0 + Vector2.from_angle(TAU * k / 7.0) * raio_m * PX_M * _rng.randf_range(0.7, 1.0))
	for y in lado:
		for x in lado:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), pontos):
				var luz := clampf(0.5 - ((x - c0.x) + (y - c0.y)) / (raio_m * PX_M * 2.0), 0.0, 1.0)
				img.set_pixel(x, y, Color(0.55, 0.5, 0.45).lightened(luz * 0.2).darkened((1.0 - luz) * 0.25))
	img.save_png(PASTA + nome + ".png")


## Objeto retangular visto de cima (m), com retângulos de detalhe por cima.
func _retangulo(nome: String, tam_m: Vector2, cor: Color, detalhes: Array) -> void:
	var img := Image.create(int(tam_m.x * PX_M), int(tam_m.y * PX_M), false, Image.FORMAT_RGBA8)
	img.fill(cor)
	for d in detalhes:
		var r: Rect2 = d[0]
		img.fill_rect(Rect2i(Vector2i(r.position * PX_M), Vector2i(r.size * PX_M)), d[1])
	# Borda mais escura: leitura de volume de cima.
	for x in img.get_width():
		for y in [0, img.get_height() - 1]:
			img.set_pixel(x, y, cor.darkened(0.3))
	for y in img.get_height():
		for x in [0, img.get_width() - 1]:
			img.set_pixel(x, y, cor.darkened(0.3))
	img.save_png(PASTA + nome + ".png")


## Poste visto de cima: base escura e a luz acesa (brilho).
func _poste() -> void:
	var lado := PX_M * 4
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(lado, lado) * 0.5
	for y in lado:
		for x in lado:
			var d := Vector2(x, y).distance_to(c) / (lado * 0.5)
			if d < 0.18:
				img.set_pixel(x, y, Color(1.0, 0.95, 0.8))
			elif d < 1.0:
				img.set_pixel(x, y, Color(1.0, 0.8, 0.5, (1.0 - d) * 0.35))
	img.save_png(PASTA + "poste.png")
