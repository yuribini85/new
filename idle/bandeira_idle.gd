class_name BandeiraIdle
extends Control
## A bandeira do fiscal por cima da corrida, no lugar do semáforo (pedido do
## usuário, 2026-10-28; nos anos 1930 a largada era dada na bandeira), no estilo
## da arte do jogo: só o pano facetado low poly (visual/shaders/bandeira.gdshader),
## sem haste, mão nem contorno (pedido do usuário). A verde entra e tremula na contagem e desce num golpe na largada, com
## o estouro "VAI!" (raios e retícula); a quadriculada agita na chegada, com
## "CHEGADA!".

## Apresentação, não balanceamento.
const PANO := Vector2(230, 150)
const DIVISOES := Vector2i(10, 5)  # poucas faces: o facetado da arte
const MARGEM := 10.0

var _pano: MeshInstance2D
var _mat: ShaderMaterial
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = PANO + Vector2.ONE * MARGEM * 2.0
	size = custom_minimum_size
	pivot_offset = Vector2(MARGEM, MARGEM + PANO.y * 0.5)  # a borda presa do pano
	_mat = _material()
	_pano = MeshInstance2D.new()
	_pano.mesh = _malha()
	_pano.material = _mat
	_pano.position = Vector2.ONE * MARGEM
	add_child(_pano)
	visible = false


func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://visual/shaders/bandeira.gdshader")
	return m


func _malha() -> ArrayMesh:
	var v := PackedVector2Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for j in DIVISOES.y + 1:
		for i in DIVISOES.x + 1:
			var u := Vector2(float(i) / DIVISOES.x, float(j) / DIVISOES.y)
			var p := u * PANO
			# Vértices de dentro um pouco fora do lugar: faces tortas como a arte.
			if i > 0 and i < DIVISOES.x and j > 0 and j < DIVISOES.y:
				p += Vector2(rng.randf_range(-6, 6), rng.randf_range(-5, 5))
			v.append(p)
			uv.append(u)
	for j in DIVISOES.y:
		for i in DIVISOES.x:
			var a := j * (DIVISOES.x + 1) + i
			# A diagonal alterna: o triângulo facetado não fica em fila.
			if (i + j) % 2 == 0:
				idx.append_array([a, a + 1, a + DIVISOES.x + 2, a, a + DIVISOES.x + 2, a + DIVISOES.x + 1])
			else:
				idx.append_array([a, a + 1, a + DIVISOES.x + 1, a + 1, a + DIVISOES.x + 2, a + DIVISOES.x + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _parar() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()


func _pano_de(quadriculada: bool, amplitude: float) -> void:
	_mat.set_shader_parameter("quadriculada", quadriculada)
	_mat.set_shader_parameter("amplitude", amplitude)


## A verde entra pela esquerda e tremula; em `contagem` segundos desce num
## golpe, com o estouro "VAI!".
func largada(contagem: float) -> void:
	_parar()
	_pano_de(false, 10.0)
	visible = true
	modulate.a = 1.0
	rotation = deg_to_rad(-6.0)
	if Preferencias.reduzir_animacoes:
		_tw = create_tween()
		_tw.tween_interval(contagem)
		_tw.tween_callback(func(): visible = false)
		return
	var x := position.x
	position.x = x - 360.0
	_tw = create_tween()
	_tw.tween_property(self, "position:x", x, minf(0.35, contagem * 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_interval(maxf(contagem - 0.55, 0.05))
	# O golpe: sobe um pouco e desce cortando o ar.
	_tw.tween_property(self, "rotation", deg_to_rad(-22.0), 0.12)
	_tw.tween_callback(func(): _estourar("VAI!", Color("e8b84a")))
	_tw.tween_property(self, "rotation", deg_to_rad(75.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(self, "modulate:a", 0.0, 0.22).set_delay(0.08)
	_tw.tween_callback(func():
		visible = false
		position.x = x
		rotation = 0.0)


## A quadriculada na chegada: entra agitando forte, com "CHEGADA!".
func chegada(dura := 2.2) -> void:
	_parar()
	_pano_de(true, 18.0)
	visible = true
	modulate.a = 1.0
	rotation = deg_to_rad(-10.0)
	_estourar("CHEGADA!", Color("ece3cc"))
	_tw = create_tween()
	if not Preferencias.reduzir_animacoes:
		for k in 4:
			_tw.tween_property(self, "rotation", deg_to_rad(-26.0), 0.18).set_trans(Tween.TRANS_SINE)
			_tw.tween_property(self, "rotation", deg_to_rad(4.0), 0.18).set_trans(Tween.TRANS_SINE)
	_tw.tween_interval(maxf(dura - 1.44, 0.2))
	_tw.tween_property(self, "modulate:a", 0.0, 0.3)
	_tw.tween_callback(func(): visible = false)


func esconder() -> void:
	_parar()
	visible = false


## O estouro de gibi no meio da corrida: raios, retícula e a palavra.
func _estourar(texto: String, cor: Color) -> void:
	var pai := get_parent() as Control
	if pai == null or Preferencias.reduzir_animacoes:
		return
	var e := _Estouro.new(texto, cor)
	e.size = Vector2(520, 300)
	e.position = (pai.size - e.size) * 0.5 + Vector2(0, -20)
	e.pivot_offset = e.size * 0.5
	pai.add_child(e)


class _Estouro extends Control:
	var texto: String
	var cor: Color
	var _t := 0.0
	const DURA := 0.8

	func _init(texto_: String, cor_: Color) -> void:
		texto = texto_
		cor = cor_
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		rotation = deg_to_rad(-4.0)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= DURA:
			queue_free()
			return
		var k := _t / DURA
		scale = Vector2.ONE * (0.6 + 0.5 * (1.0 - pow(1.0 - minf(k * 3.0, 1.0), 3.0)))
		modulate.a = 1.0 - smoothstep(0.6, 1.0, k)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		# Raios do estouro, alternando duas cores, com pontas irregulares.
		var n := 18
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var r := 250.0 if i % 2 == 0 else 200.0
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a0) * Vector2(r, r * 0.55),
					c + Vector2.from_angle(a1) * Vector2(r * 0.9, r * 0.5)])
			draw_colored_polygon(pts, Color(cor, 0.85) if i % 2 == 0 else Color(cor.darkened(0.35), 0.85))
		# Retícula de pontos no anel do meio.
		for i in 60:
			var a := TAU * i / 60.0
			for j in 3:
				var p := c + Vector2.from_angle(a) * Vector2(110 + j * 22, (110 + j * 22) * 0.55)
				draw_circle(p, 5.0 - j * 1.2, Color(0.07, 0.05, 0.04, 0.5))
		# A palavra na letra dos balões, com contorno grosso.
		var f := Tipografia.fonte("fala")
		var tam := 84
		var w := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		var p0 := c + Vector2(-w * 0.5, tam * 0.35)
		draw_string_outline(f, p0 + Vector2(4, 5), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 14, Color(0.07, 0.05, 0.04))
		draw_string_outline(f, p0, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 10, Color(0.07, 0.05, 0.04))
		draw_string(f, p0, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color("fff4d6"))
