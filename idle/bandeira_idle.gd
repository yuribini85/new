class_name BandeiraIdle
extends Control
## A bandeira do fiscal por cima da corrida, no lugar do semáforo (pedido do
## usuário, 2026-10-28; nos anos 1930 a largada era dada na bandeira): a verde
## entra e tremula durante a contagem e desce num golpe na largada; a
## quadriculada tremula na chegada. Pano numa malha subdividida que ondula no
## shader (visual/shaders/bandeira.gdshader), haste de madeira.

## Apresentação, não balanceamento.
const PANO := Vector2(230, 150)
const DIVISOES := Vector2i(24, 10)
const HASTE := Color("5b3d22")

var _pano: MeshInstance2D
var _mat: ShaderMaterial
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANO.x + 40, PANO.y + 140)
	size = custom_minimum_size
	pivot_offset = Vector2(14, PANO.y + 130)  # a mão do fiscal, no pé da haste
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://visual/shaders/bandeira.gdshader")
	_pano = MeshInstance2D.new()
	_pano.mesh = _malha()
	_pano.material = _mat
	_pano.position = Vector2(14, 6)
	add_child(_pano)
	visible = false


func _malha() -> ArrayMesh:
	var v := PackedVector2Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in DIVISOES.y + 1:
		for i in DIVISOES.x + 1:
			var u := Vector2(float(i) / DIVISOES.x, float(j) / DIVISOES.y)
			v.append(u * PANO)
			uv.append(u)
	for j in DIVISOES.y:
		for i in DIVISOES.x:
			var a := j * (DIVISOES.x + 1) + i
			idx.append_array([a, a + 1, a + DIVISOES.x + 2, a, a + DIVISOES.x + 2, a + DIVISOES.x + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _draw() -> void:
	# Haste de madeira com a ponta de latão.
	draw_rect(Rect2(8, 0, 7, PANO.y + 132), HASTE)
	draw_rect(Rect2(10, 0, 2, PANO.y + 132), HASTE.lightened(0.25))
	draw_circle(Vector2(11.5, 0), 7.0, IdleUI.COR_OURO)


func _parar() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()


## A verde entra pela esquerda e tremula; em `contagem` segundos desce num
## golpe e sai (a largada).
func largada(contagem: float) -> void:
	_parar()
	_mat.set_shader_parameter("quadriculada", false)
	_mat.set_shader_parameter("amplitude", 10.0)
	visible = true
	modulate.a = 1.0
	rotation = deg_to_rad(-8.0)
	if Preferencias.reduzir_animacoes:
		_tw = create_tween()
		_tw.tween_interval(contagem)
		_tw.tween_callback(func(): visible = false)
		return
	var x := position.x
	position.x = x - 320.0
	_tw = create_tween()
	_tw.tween_property(self, "position:x", x, minf(0.35, contagem * 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_interval(maxf(contagem - 0.55, 0.05))
	# O golpe: a bandeira sobe um pouco e desce cortando o ar.
	_tw.tween_property(self, "rotation", deg_to_rad(-24.0), 0.12)
	_tw.tween_property(self, "rotation", deg_to_rad(70.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25).set_delay(0.08)
	_tw.tween_callback(func():
		visible = false
		position.x = x
		rotation = 0.0)


## A quadriculada na chegada: entra agitando forte e some sozinha.
func chegada(dura := 2.2) -> void:
	_parar()
	_mat.set_shader_parameter("quadriculada", true)
	_mat.set_shader_parameter("amplitude", 18.0)
	visible = true
	modulate.a = 1.0
	rotation = deg_to_rad(-10.0)
	_tw = create_tween()
	if not Preferencias.reduzir_animacoes:
		# Agitando: a haste vai e volta.
		for k in 4:
			_tw.tween_property(self, "rotation", deg_to_rad(-26.0), 0.18).set_trans(Tween.TRANS_SINE)
			_tw.tween_property(self, "rotation", deg_to_rad(4.0), 0.18).set_trans(Tween.TRANS_SINE)
	_tw.tween_interval(maxf(dura - 1.44, 0.2))
	_tw.tween_property(self, "modulate:a", 0.0, 0.3)
	_tw.tween_callback(func(): visible = false)


func esconder() -> void:
	_parar()
	visible = false
