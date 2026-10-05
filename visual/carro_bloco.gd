class_name CarroBloco
extends Node3D
## Carro 3D original gerado em código: carroceria contínua (para-choques,
## capô, para-brisa, teto, vigia, traseira) feita por seções ao longo do
## comprimento, mais rodas, faróis e lanternas. Comprido no eixo +X local (o
## rumo da pista gira em Y). As proporções seguem a categoria; nada de modelo
## real. A troca por modelo definitivo mantém `configurar(categoria, cor)`.

## Medidas de placeholder por categoria (m): comprimento, largura, altura do
## chassi, cabine (fração do comprimento, altura, recuo) e se tem teto.
const FORMAS := {
	"compacto": {"c": 3.8, "l": 1.65, "h": 0.65, "cab": 0.55, "hc": 0.6, "recuo": -0.15, "teto": true},
	"seda": {"c": 4.6, "l": 1.75, "h": 0.6, "cab": 0.48, "hc": 0.55, "recuo": -0.1, "teto": true},
	"cupe": {"c": 4.4, "l": 1.75, "h": 0.55, "cab": 0.38, "hc": 0.45, "recuo": -0.2, "teto": true},
	"roadster": {"c": 4.0, "l": 1.7, "h": 0.55, "cab": 0.2, "hc": 0.3, "recuo": -0.05, "teto": false},
}
const RAIO_RODA := 0.33

var comprimento := 4.5
var largura := 1.8


func configurar(categoria: String, cor: Color) -> CarroBloco:
	for c in get_children():
		c.queue_free()
	var f: Dictionary = FORMAS.get(categoria, FORMAS["seda"])
	comprimento = f["c"]
	largura = f["l"]
	var pintura := _material(cor)
	var base_y := RAIO_RODA * 0.9
	var vidro := _material(cor.darkened(0.6))
	var corpo := MeshInstance3D.new()
	corpo.mesh = carroceria(f, cor)
	add_child(corpo)
	# Faróis e lanternas: dá para ver para que lado o carro anda.
	var farol := _material(Color(1.0, 0.95, 0.7))
	var lanterna := _material(Color(0.9, 0.1, 0.1))
	for z in [-1.0, 1.0]:
		_caixa(Vector3(0.06, 0.14, 0.3), Vector3(comprimento * 0.5, base_y + f["h"] * 0.6, z * largura * 0.32), farol)
		_caixa(Vector3(0.06, 0.12, 0.3), Vector3(-comprimento * 0.5, base_y + f["h"] * 0.6, z * largura * 0.32), lanterna)
	# Silhueta por categoria: aerofólio no cupê, santantônio no roadster.
	if categoria == "cupe":
		_caixa(Vector3(0.25, 0.06, largura * 0.9), Vector3(-comprimento * 0.46, base_y + f["h"] + 0.28, 0), pintura.duplicate())
		for z in [-1.0, 1.0]:
			_caixa(Vector3(0.08, 0.26, 0.08), Vector3(-comprimento * 0.46, base_y + f["h"] + 0.13, z * largura * 0.3), vidro)
	elif categoria == "roadster":
		_caixa(Vector3(0.1, 0.45, largura * 0.7), Vector3(-comprimento * 0.15, base_y + f["h"] + 0.22, 0), _material(Color(0.2, 0.2, 0.22)))
	var pneu := _material(Color(0.08, 0.08, 0.09))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var roda := MeshInstance3D.new()
			var m := CylinderMesh.new()
			m.top_radius = RAIO_RODA
			m.bottom_radius = RAIO_RODA
			m.height = 0.24
			m.radial_segments = 10
			m.rings = 1
			roda.mesh = m
			roda.material_override = pneu
			roda.rotation = Vector3(PI / 2.0, 0, 0)
			roda.position = Vector3(x * comprimento * 0.32, RAIO_RODA, z * (largura * 0.5 - 0.06))
			add_child(roda)
	return self


## Altura do topo da carroceria na posição x (m, do centro do carro): para-
## choque, capô, para-brisa, teto, vigia e tampa traseira. Também diz se ali é
## vidro (greenhouse).
static func perfil(f: Dictionary, x: float) -> Array:
	var c: float = f["c"]
	var base_y := RAIO_RODA * 0.9
	var cintura: float = base_y + f["h"]
	var teto: float = cintura + f["hc"]
	var xc: float = c * f["recuo"]
	var lc: float = c * f["cab"]
	var tras := xc - lc * 0.5
	var frente := xc + lc * 0.5
	var t := (x + c * 0.5) / c  # 0 na traseira, 1 na frente
	var topo := cintura
	if t < 0.05:
		topo = lerpf(cintura - 0.12, cintura, t / 0.05)
	elif t > 0.9:
		topo = lerpf(cintura - 0.04, cintura - 0.16, (t - 0.9) / 0.1)
	elif x > frente:
		topo = lerpf(cintura, cintura - 0.04, (x - frente) / maxf(c * 0.9 - c * 0.5 - frente, 0.01))
	if not f["teto"]:
		# Roadster: só o para-brisa, inclinado, na frente do cockpit.
		if x > frente - lc * 0.35 and x <= frente:
			return [lerpf(cintura + f["hc"], cintura, (x - (frente - lc * 0.35)) / (lc * 0.35)), true]
		return [topo, false]
	if x >= tras and x <= frente:
		var subida := lc * 0.22
		var descida := lc * 0.28
		if x < tras + subida:
			return [lerpf(cintura, teto, (x - tras) / subida), true]
		if x > frente - descida:
			return [lerpf(teto, cintura, (x - (frente - descida)) / descida), true]
		return [teto, true]
	return [topo, false]


## Malha da carroceria: seções transversais ao longo do comprimento, ligadas
## em faixas; sombreamento chapado (low-poly). Vidro em cor mais escura.
static func carroceria(f: Dictionary, cor: Color) -> ArrayMesh:
	var c: float = f["c"]
	var l: float = f["l"]
	var base_y := RAIO_RODA * 0.9
	var cintura: float = base_y + f["h"]
	var y0 := 0.2
	var estacoes := 28
	var secoes := []
	var vidros := []
	var topos := []
	for i in estacoes + 1:
		var x := -c * 0.5 + c * i / estacoes
		var t := float(i) / estacoes
		var p := perfil(f, x)
		var topo: float = p[0]
		# Largura afina nas pontas (para-choques arredondados em planta).
		var meia := l * 0.5 * (0.86 + 0.14 * sin(PI * clampf(t * 1.25 - 0.125, 0.0, 1.0)))
		var ombro := minf(topo, cintura)
		var sec := [
			Vector2(meia * 0.92, y0), Vector2(meia, y0 + (ombro - y0) * 0.55),
			Vector2(meia * 0.97, ombro),
			Vector2(meia * (0.78 if topo > cintura + 0.02 else 0.9), topo),
			Vector2(0.0, topo),
		]
		secoes.append(sec.map(func(q): return Vector3(x, q.y, q.x)))
		vidros.append(p[1] and topo > cintura + 0.02)
		topos.append(topo)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cor_vidro := cor.darkened(0.65)
	for i in estacoes:
		var a: Array = secoes[i]
		var b: Array = secoes[i + 1]
		for k in a.size() - 1:
			# Laterais do greenhouse e as faces inclinadas (para-brisa, vigia).
			var eh_vidro: bool = (k == 2 and (vidros[i] or vidros[i + 1])) or (k == 3 and vidros[i] and vidros[i + 1]
					and absf(float(topos[i]) - float(topos[i + 1])) > 0.01)
			var cor_q := cor_vidro if eh_vidro else (cor.darkened(0.08) if k == 0 else cor)
			for lado in [1.0, -1.0]:
				var q := [a[k], b[k], b[k + 1], a[k + 1]].map(func(v): return Vector3(v.x, v.y, v.z * lado))
				_quad(st, q, cor_q, lado < 0.0)
	# Tampas da frente e de trás.
	for ponta in [0, estacoes]:
		var sec: Array = secoes[ponta]
		for lado in [1.0, -1.0]:
			for k in sec.size() - 1:
				var tri := [Vector3(sec[0].x, (sec[0].y + sec[sec.size() - 1].y) * 0.5, 0.0),
						Vector3(sec[k].x, sec[k].y, sec[k].z * lado), Vector3(sec[k + 1].x, sec[k + 1].y, sec[k + 1].z * lado)]
				var inverter: bool = (ponta == 0) != (lado < 0.0)
				for v in ([tri[0], tri[2], tri[1]] if inverter else tri):
					st.set_color(cor.darkened(0.15))
					st.add_vertex(v)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.45
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := st.commit()
	m.surface_set_material(0, mat)
	return m


static func _quad(st: SurfaceTool, q: Array, cor: Color, inverter: bool) -> void:
	var tris := [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]
	for t in tris:
		for v in ([t[0], t[2], t[1]] if inverter else t):
			st.set_color(cor)
			st.add_vertex(v)


## Cor estável derivada do id, para carros sem cor definida (garagem, loja).
static func cor_do_id(id: String) -> Color:
	return Color.from_hsv(float(posmod(id.hash(), 360)) / 360.0, 0.6, 0.85)


func _caixa(tam: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


static func _material(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.6
	return m
