class_name MontagemMalha
extends RefCounted
## Junta as peças de um carro gerado (Carroceria, Rodas) em poucas superfícies:
## a pintura (shader da lataria, por instância) e o resto numa superfície só
## (shaders/carro_detalhe.gdshader), cada vértice com o próprio material. Num
## celular cada superfície é uma chamada de desenho: um carro com uma peça por
## nó passava de cem.
##
## Facetado (pedido do usuário: "como os pilotos"): sem índices, uma normal por
## triângulo, a mesma regra do SurfaceTool.generate_normals.

const SHADER_DETALHE := preload("res://visual/shaders/carro_detalhe.gdshader")
const PINTURA := "pintura"

## Materiais das peças: [cor (sRGB), metálico, rugosidade, emissão relativa à
## cor, especular]. A emissão das luzes é a do protótipo aprovado.
const ESTILOS := {
	"preto": [Color(0.045, 0.045, 0.05), 0.0, 0.7, 0.0, 0.5],
	"borracha": [Color(0.06, 0.06, 0.065), 0.0, 0.9, 0.0, 0.5],
	"cromo": [Color(0.85, 0.86, 0.88), 1.0, 0.12, 0.0, 0.5],
	"aro": [Color(0.7, 0.72, 0.75), 0.9, 0.25, 0.0, 0.5],
	"aro_escuro": [Color(0.18, 0.18, 0.2), 0.7, 0.35, 0.0, 0.5],
	"vidro": [Color(0.17, 0.22, 0.29), 0.35, 0.03, 0.0, 1.0],
	"re": [Color(0.85, 0.85, 0.85), 0.0, 0.15, 0.0, 0.5],
	"farol": [Color(0.92, 0.94, 0.96), 0.0, 0.1, 0.8, 0.5],
	"lanterna": [Color(0.55, 0.04, 0.05), 0.0, 0.15, 3.0, 0.5],
	"seta": [Color(0.95, 0.55, 0.1), 0.0, 0.2, 0.45, 0.5],
	"placa": [Color(0.82, 0.82, 0.78), 0.0, 0.5, 0.0, 0.5],
	"interno": [Color(0.02, 0.02, 0.022), 0.0, 1.0, 0.0, 0.5],
	# rodas
	"pneu": [Color(0.07, 0.07, 0.075), 0.0, 0.92, 0.0, 0.5],
	"flanco": [Color(0.11, 0.11, 0.115), 0.0, 0.85, 0.0, 0.5],
	"aro_roda": [Color(0.78, 0.8, 0.83), 0.7, 0.3, 0.0, 0.5],
	"aro_roda_escuro": [Color(0.16, 0.16, 0.18), 0.6, 0.4, 0.0, 0.5],
	"cromo_roda": [Color(0.9, 0.91, 0.93), 0.75, 0.22, 0.0, 0.5],
	"freio": [Color(0.32, 0.31, 0.3), 0.6, 0.5, 0.0, 0.5],
	"pinca": [Color(0.7, 0.12, 0.1), 0.0, 0.4, 0.0, 0.5],
	# carros de época (CarroEpoca)
	"paralama": [Color(0.035, 0.035, 0.04), 0.2, 0.16, 0.0, 0.7],
	"lona": [Color(0.05, 0.05, 0.05), 0.0, 0.95, 0.0, 0.3],
	"raio": [Color(0.82, 0.76, 0.6), 0.1, 0.35, 0.0, 0.5],
	# rodas pintadas dos carros de época (PinturaEpoca)
	"roda_creme": [Color(0.82, 0.76, 0.6), 0.1, 0.35, 0.0, 0.5],
	"roda_vinho": [Color(0.36, 0.07, 0.08), 0.1, 0.3, 0.0, 0.6],
	"roda_vermelha": [Color(0.62, 0.1, 0.08), 0.1, 0.3, 0.0, 0.6],
	"roda_preta": [Color(0.05, 0.05, 0.055), 0.1, 0.3, 0.0, 0.6],
	"roda_marfim": [Color(0.88, 0.85, 0.76), 0.1, 0.3, 0.0, 0.6],
	"roda_azul": [Color(0.12, 0.2, 0.38), 0.1, 0.3, 0.0, 0.6],
	"roda_verde": [Color(0.13, 0.25, 0.17), 0.1, 0.3, 0.0, 0.6],
	"vidro_epoca": [Color(0.24, 0.27, 0.3), 0.5, 0.04, 0.0, 1.0],
	"cromo_epoca": [Color(0.8, 0.81, 0.84), 0.55, 0.2, 0.14, 0.9],
	"lente": [Color(0.86, 0.88, 0.9), 0.4, 0.05, 0.35, 0.8],
}

static var _material: ShaderMaterial
## Malhas-base das primitivas (chave -> PackedVector3Array em triângulos).
static var _base := {}
## estilo -> [cor linear, uv, uv2]
static var _atributos := {}

## Vértices de uma superfície (classe: arrays empacotados guardados num
## Dictionary voltam como cópia, e o append se perderia). Os atributos do
## material vão por trechos [estilo, vértices] e são preenchidos no fim.
class Grupo:
	var v := PackedVector3Array()
	var trechos: Array = []

	func estilo(e: String, n: int) -> void:
		if not trechos.is_empty() and trechos[-1][0] == e:
			trechos[-1][1] += n
		else:
			trechos.append([e, n])


var _grupos := {}  # PINTURA ou "detalhe" -> Grupo


## O material de tudo o que não é pintura (um só para todos os carros).
static func material_detalhe() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER_DETALHE
	return _material


static func _attr(estilo: String) -> Array:
	if not _atributos.has(estilo):
		var e: Array = ESTILOS.get(estilo, ESTILOS["preto"])
		_atributos[estilo] = [(e[0] as Color).srgb_to_linear(), Vector2(e[1], e[2]), Vector2(e[3], e[4])]
	return _atributos[estilo]


func _grupo(estilo: String) -> Grupo:
	var g := PINTURA if estilo == PINTURA else "detalhe"
	if not _grupos.has(g):
		_grupos[g] = Grupo.new()
	return _grupos[g]


## Um triângulo, na ordem dada (a normal sai dela, como no SurfaceTool).
func tri(estilo: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var g := _grupo(estilo)
	g.v.append(a)
	g.v.append(b)
	g.v.append(c)
	g.estilo(estilo, 3)


## Triângulos soltos (de três em três) transformados por `xf`.
func triangulos(estilo: String, vs: PackedVector3Array, xf: Transform3D) -> void:
	var g := _grupo(estilo)
	g.v.append_array(xf * vs)
	g.estilo(estilo, vs.size())


## Caixa de tamanho `tam`, centrada; `xf` posiciona (e gira/escala).
func caixa(estilo: String, tam: Vector3, xf: Transform3D) -> void:
	triangulos(estilo, _primitiva("caixa"), xf * Transform3D(Basis.from_scale(tam), Vector3.ZERO))


## Cilindro em Y (raio, altura, lados).
func cilindro(estilo: String, raio: float, alt: float, lados: int, xf: Transform3D) -> void:
	triangulos(estilo, _primitiva("cilindro%d" % lados), xf * Transform3D(Basis.from_scale(Vector3(raio, alt, raio)), Vector3.ZERO))


## Elipsoide com raio e altura (como o SphereMesh), `lados` x `aneis`.
func esfera(estilo: String, raio: float, alt: float, lados: int, aneis: int, xf: Transform3D) -> void:
	triangulos(estilo, _primitiva("esfera%d_%d" % [lados, aneis]),
			xf * Transform3D(Basis.from_scale(Vector3(raio * 2.0, alt, raio * 2.0)), Vector3.ZERO))


## Primitiva unitária em triângulos soltos (caixa 1x1x1, cilindro de raio 1 e
## altura 1, esfera de diâmetro 1).
static func _primitiva(chave: String) -> PackedVector3Array:
	if _base.has(chave):
		return _base[chave]
	var m: PrimitiveMesh
	if chave == "caixa":
		m = BoxMesh.new()
	elif chave.begins_with("cilindro"):
		var c := CylinderMesh.new()
		c.top_radius = 1.0
		c.bottom_radius = 1.0
		c.height = 1.0
		c.radial_segments = int(chave.substr(8))
		c.rings = 1
		m = c
	else:
		var p := chave.substr(6).split("_")
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = int(p[0])
		s.rings = int(p[1])
		m = s
	var arr := m.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out := PackedVector3Array()
	for i in idx:
		out.append(vs[i])
	_base[chave] = out
	return out


## Transformação de nó: posição, rotação (Euler, ordem do Node3D) e escala.
static func xf(pos: Vector3, rot := Vector3.ZERO, escala := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(escala), pos)


## Uma normal por triângulo, pela ordem dos vértices (Plane(a, b, c), como o
## SurfaceTool.generate_normals).
static func _normais(v: PackedVector3Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(v.size())
	var i := 0
	while i + 2 < v.size():
		var a := v[i]
		var q := (a - v[i + 2]).cross(a - v[i + 1])
		q = q.normalized() if q.length_squared() > 1e-14 else Vector3.UP
		n[i] = q
		n[i + 1] = q
		n[i + 2] = q
		i += 3
	return n


func vazia() -> bool:
	return _grupos.is_empty()


## A malha pronta: a pintura (se houver) na superfície 0, o resto depois. A
## meta "pintura" guarda o índice da superfície pintada (-1 sem).
func malha() -> ArrayMesh:
	var m := ArrayMesh.new()
	var pintura := -1
	for g in [PINTURA, "detalhe"]:
		if not _grupos.has(g):
			continue
		var gr: Grupo = _grupos[g]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = gr.v
		arr[Mesh.ARRAY_NORMAL] = _normais(gr.v)
		if g != PINTURA:
			var cores := PackedColorArray()
			var uv := PackedVector2Array()
			var uv2 := PackedVector2Array()
			for t in gr.trechos:
				var at := _attr(t[0])
				var k0 := cores.size()
				cores.resize(k0 + t[1])
				uv.resize(k0 + t[1])
				uv2.resize(k0 + t[1])
				for i in range(k0, k0 + t[1]):
					cores[i] = at[0]
					uv[i] = at[1]
					uv2[i] = at[2]
			arr[Mesh.ARRAY_COLOR] = cores
			arr[Mesh.ARRAY_TEX_UV] = uv
			arr[Mesh.ARRAY_TEX_UV2] = uv2
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var k := m.get_surface_count() - 1
		if g == PINTURA:
			pintura = k
		else:
			m.surface_set_material(k, material_detalhe())
		m.surface_set_name(k, g)
	m.set_meta("pintura", pintura)
	return m
