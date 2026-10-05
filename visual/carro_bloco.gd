class_name CarroBloco
extends Node3D
## Carro 3D original gerado em código (nenhum modelo real): carroceria contínua
## por seções ao longo do comprimento, caixas de roda, rodas com aro e raios,
## grade, faróis, lanternas, retrovisores e sombra. Comprido no eixo +X local
## (o rumo da pista gira em Y).
##
## Cada categoria tem uma silhueta (hatch, sedã, cupê, esportivo aberto) e cada
## modelo varia dentro dela pelos próprios números (potência, peso), de forma
## estável: o mesmo carro sempre tem a mesma cara.

## Silhueta por categoria (m): comprimento, largura, altura da cintura, cabine
## (fração do comprimento, altura, recuo do centro) e se tem teto.
const FORMAS := {
	"compacto": {"c": 3.8, "l": 1.66, "h": 0.62, "cab": 0.56, "hc": 0.62, "recuo": -0.14, "teto": true},
	"seda": {"c": 4.6, "l": 1.76, "h": 0.6, "cab": 0.46, "hc": 0.56, "recuo": -0.06, "teto": true},
	"cupe": {"c": 4.35, "l": 1.74, "h": 0.54, "cab": 0.4, "hc": 0.48, "recuo": -0.14, "teto": true},
	"roadster": {"c": 4.0, "l": 1.72, "h": 0.52, "cab": 0.22, "hc": 0.32, "recuo": -0.06, "teto": false},
}
const RAIO_RODA := 0.33
const PINTURAS := [
	Color(0.85, 0.12, 0.12), Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.14), Color(0.15, 0.35, 0.8),
	Color(0.98, 0.78, 0.1), Color(0.2, 0.6, 0.3), Color(0.6, 0.62, 0.66), Color(0.95, 0.45, 0.1),
]

var comprimento := 4.5
var largura := 1.8
var _rodas: Array = []


## Silhueta só pela categoria (usado onde não há modelo).
func configurar(categoria: String, cor: Color) -> CarroBloco:
	return configurar_modelo({"id": categoria, "categoria": categoria}, cor)


## Silhueta da categoria com as variações do modelo.
func configurar_modelo(base: Dictionary, cor: Color) -> CarroBloco:
	for c in get_children():
		c.queue_free()
	_rodas = []
	var f := forma(base)
	comprimento = f["c"]
	largura = f["l"]
	var r: float = f["roda"]
	var corpo := MeshInstance3D.new()
	corpo.mesh = carroceria(f, cor)
	add_child(corpo)
	var cintura: float = r * 0.9 + f["h"]
	var escuro := _material(Color(0.06, 0.06, 0.07))
	var cromado := _material(Color(0.78, 0.8, 0.84))
	cromado.metallic = 0.8
	cromado.roughness = 0.25
	_caixa(Vector3(0.05, 0.16, largura * 0.5), Vector3(comprimento * 0.5 + 0.005, r * 0.9 + f["h"] * 0.35, 0), escuro)
	var farol := _material(Color(1.0, 0.96, 0.78))
	farol.emission_enabled = true
	farol.emission = Color(1.0, 0.95, 0.75) * 0.6
	var lanterna := _material(Color(0.85, 0.08, 0.08))
	lanterna.emission_enabled = true
	lanterna.emission = Color(0.6, 0.02, 0.02)
	for z in [-1.0, 1.0]:
		_caixa(Vector3(0.05, 0.11, 0.34), Vector3(comprimento * 0.5 - 0.01, cintura - 0.17, z * largura * 0.33), farol)
		_caixa(Vector3(0.05, 0.1, 0.36), Vector3(-comprimento * 0.5 + 0.01, cintura - 0.12, z * largura * 0.33), lanterna)
		if f["teto"]:
			var xr: float = comprimento * f["recuo"] + comprimento * f["cab"] * 0.36
			_caixa(Vector3(0.12, 0.09, 0.14), Vector3(xr, cintura + 0.06, z * (largura * 0.5 + 0.05)), _material(cor.darkened(0.2)))
	match f["estilo"]:
		"cupe":
			if f["aerofolio"]:
				_caixa(Vector3(0.28, 0.05, largura * 0.92), Vector3(-comprimento * 0.47, cintura + 0.24, 0), _material(cor.darkened(0.1)))
				for z in [-1.0, 1.0]:
					_caixa(Vector3(0.08, 0.22, 0.06), Vector3(-comprimento * 0.47, cintura + 0.11, z * largura * 0.32), escuro)
		"esportivo":
			_caixa(Vector3(0.08, 0.38, largura * 0.62), Vector3(-comprimento * 0.13, cintura + 0.19, 0), escuro)
		"hatch":
			var xt: float = comprimento * f["recuo"] - comprimento * f["cab"] * 0.5
			_caixa(Vector3(0.18, 0.04, largura * 0.8), Vector3(xt - 0.02, cintura + f["hc"] - 0.02, 0), _material(cor.darkened(0.15)))
	var pneu := _material(Color(0.07, 0.07, 0.08))
	var entre: float = comprimento * f["entre_eixos"] * 0.5
	for x in [-entre, entre]:
		for z in [-1.0, 1.0]:
			var caixa_roda := MeshInstance3D.new()
			caixa_roda.mesh = _cilindro(r + 0.06, 0.3)
			caixa_roda.material_override = escuro
			caixa_roda.rotation = Vector3(PI / 2.0, 0, 0)
			caixa_roda.position = Vector3(x, r + 0.02, z * (largura * 0.5 - 0.13))
			add_child(caixa_roda)
			var roda := Node3D.new()
			roda.position = Vector3(x, r, z * (largura * 0.5 - 0.1))
			add_child(roda)
			var p := MeshInstance3D.new()
			p.mesh = _cilindro(r, 0.24)
			p.material_override = pneu
			p.rotation = Vector3(PI / 2.0, 0, 0)
			roda.add_child(p)
			var aro := MeshInstance3D.new()
			aro.mesh = _cilindro(r * 0.62, 0.02)
			aro.material_override = cromado
			aro.rotation = Vector3(PI / 2.0, 0, 0)
			aro.position.z = z * 0.125
			roda.add_child(aro)
			for k in int(f["raios"]):
				var raio := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(r * 1.1, 0.06, 0.02)
				raio.mesh = b
				raio.material_override = escuro
				raio.position.z = z * 0.137
				raio.rotation.z = PI * k / float(f["raios"])
				roda.add_child(raio)
			_rodas.append(roda)
	var sombra := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(comprimento * 1.05, largura * 1.15)
	sombra.mesh = q
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0, 0, 0, 0.45)
	ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ms.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sombra.material_override = ms
	sombra.position.y = 0.02
	add_child(sombra)
	return self


## Gira as rodas pela distância andada (m).
func girar_rodas(distancia: float) -> void:
	for roda in _rodas:
		roda.rotation.z -= distancia / RAIO_RODA


## Forma completa do modelo: a da categoria mais variações tiradas dos números
## do carro (sempre as mesmas para o mesmo carro).
static func forma(base: Dictionary) -> Dictionary:
	var cat: String = base.get("categoria", "seda")
	var f: Dictionary = FORMAS.get(cat, FORMAS["seda"]).duplicate()
	f["estilo"] = {"compacto": "hatch", "seda": "seda", "cupe": "cupe", "roadster": "esportivo"}.get(cat, "seda")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(base.get("id", cat)))
	var potencia := float(base.get("potencia", 150.0))
	var peso := float(base.get("peso", 1100.0))
	# Mais potência por kg: carro mais baixo, rodas maiores; mais peso: maior.
	var esportividade := clampf((potencia / maxf(peso, 1.0) - 0.1) / 0.25, 0.0, 1.0)
	var porte := clampf((peso - 700.0) / 800.0, 0.0, 1.0)
	f["c"] = f["c"] * lerpf(0.94, 1.06, porte) * rng.randf_range(0.98, 1.02)
	f["l"] = f["l"] * lerpf(0.97, 1.04, porte)
	f["hc"] = f["hc"] * lerpf(1.04, 0.88, esportividade) * rng.randf_range(0.96, 1.04)
	f["h"] = f["h"] * rng.randf_range(0.95, 1.05)
	f["cab"] = f["cab"] * rng.randf_range(0.94, 1.06)
	f["roda"] = RAIO_RODA * lerpf(0.92, 1.1, esportividade)
	f["raios"] = 5 if esportividade > 0.5 else (4 if rng.randf() < 0.5 else 6)
	f["entre_eixos"] = rng.randf_range(0.6, 0.66)
	f["aerofolio"] = cat == "cupe" and esportividade > 0.35
	f["bico"] = rng.randf_range(0.0, 1.0)
	return f


## Altura do topo da carroceria em x (m, do centro) e se ali é vidro.
static func perfil(f: Dictionary, x: float) -> Array:
	var c: float = f["c"]
	var cintura: float = f.get("roda", RAIO_RODA) * 0.9 + f["h"]
	var teto: float = cintura + f["hc"]
	var xc: float = c * f["recuo"]
	var lc: float = c * f["cab"]
	var tras := xc - lc * 0.5
	var frente := xc + lc * 0.5
	var t := (x + c * 0.5) / c
	var queda: float = lerpf(0.1, 0.22, f.get("bico", 0.5))
	var topo := cintura
	if t < 0.05:
		topo = lerpf(cintura - 0.1, cintura, t / 0.05)
	elif x > frente:
		topo = lerpf(cintura, cintura - queda, pow(clampf((x - frente) / maxf(c * 0.5 - frente, 0.01), 0.0, 1.0), 1.6))
	if not f["teto"]:
		if x > frente - lc * 0.4 and x <= frente:
			return [lerpf(cintura + f["hc"], cintura, (x - (frente - lc * 0.4)) / (lc * 0.4)), true]
		return [topo, false]
	if x >= tras and x <= frente:
		var estilo: String = f.get("estilo", "seda")
		# Hatch: traseira quase reta; cupê: caimento longo; sedã: vigia curta.
		var subida: float = lc * {"hatch": 0.1, "cupe": 0.4, "seda": 0.22}.get(estilo, 0.22)
		var descida := lc * 0.3
		if x < tras + subida:
			return [lerpf(cintura, teto, (x - tras) / subida), true]
		if x > frente - descida:
			return [lerpf(teto, cintura, (x - (frente - descida)) / descida), true]
		return [teto, true]
	if f.get("estilo", "") == "seda" and x < tras:
		return [cintura + 0.05, false]
	return [topo, false]


## Malha da carroceria: seções ligadas em faixas, sombreamento chapado, vidro
## escuro, para-lamas alargados sobre as rodas.
static func carroceria(f: Dictionary, cor: Color) -> ArrayMesh:
	var c: float = f["c"]
	var l: float = f["l"]
	var r: float = f.get("roda", RAIO_RODA)
	var cintura: float = r * 0.9 + f["h"]
	var y0 := 0.18
	var estacoes := 36
	var entre: float = c * f.get("entre_eixos", 0.62) * 0.5
	var secoes := []
	var vidros := []
	var topos := []
	for i in estacoes + 1:
		var x := -c * 0.5 + c * i / estacoes
		var t := float(i) / estacoes
		var p := perfil(f, x)
		var topo: float = p[0]
		var meia := l * 0.5 * (0.84 + 0.16 * sin(PI * clampf(t * 1.3 - 0.15, 0.0, 1.0)))
		var lama := 0.0
		for ex in [-entre, entre]:
			lama = maxf(lama, 1.0 - clampf(absf(x - ex) / (r * 1.6), 0.0, 1.0))
		var lado := meia * (1.0 + 0.035 * lama)
		var ombro := minf(topo, cintura)
		var vid: bool = p[1] and topo > cintura + 0.02
		secoes.append([
			Vector3(x, y0, lado * 0.9), Vector3(x, y0 + 0.08, lado), Vector3(x, (y0 + ombro) * 0.5 + 0.05, lado),
			Vector3(x, ombro - 0.02, lado * 0.98), Vector3(x, ombro, lado * 0.93),
			Vector3(x, topo, lado * (0.74 if vid else 0.88)), Vector3(x, topo + (0.015 if vid else 0.0), 0.0),
		])
		vidros.append(vid)
		topos.append(topo)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cor_vidro := Color(0.08, 0.1, 0.13)
	for i in estacoes:
		var a: Array = secoes[i]
		var b: Array = secoes[i + 1]
		for k in a.size() - 1:
			var eh_vidro: bool = (k == 4 and (vidros[i] or vidros[i + 1])) or (k == 5 and vidros[i] and vidros[i + 1]
					and absf(float(topos[i]) - float(topos[i + 1])) > 0.01)
			var cor_q := cor_vidro if eh_vidro else (Color(0.08, 0.08, 0.09) if k == 0 else (cor.darkened(0.12) if k == 1 else cor))
			for lado in [1.0, -1.0]:
				var q := [a[k], b[k], b[k + 1], a[k + 1]].map(func(v): return Vector3(v.x, v.y, v.z * lado))
				_quad(st, q, cor_q, lado < 0.0)
	for ponta in [0, estacoes]:
		var sec: Array = secoes[ponta]
		var centro := Vector3(sec[0].x, (sec[0].y + sec[sec.size() - 1].y) * 0.5, 0.0)
		for lado in [1.0, -1.0]:
			for k in sec.size() - 1:
				var tri := [centro, Vector3(sec[k].x, sec[k].y, sec[k].z * lado), Vector3(sec[k + 1].x, sec[k + 1].y, sec[k + 1].z * lado)]
				var inverter: bool = (ponta == 0) != (lado < 0.0)
				for v in ([tri[0], tri[2], tri[1]] if inverter else tri):
					st.set_color(cor.darkened(0.18))
					st.add_vertex(v)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.35
	mat.metallic = 0.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := st.commit()
	m.surface_set_material(0, mat)
	return m


static func _quad(st: SurfaceTool, q: Array, cor: Color, inverter: bool) -> void:
	for t in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
		for v in ([t[0], t[2], t[1]] if inverter else t):
			st.set_color(cor)
			st.add_vertex(v)


## Cor de fábrica estável derivada do id (sem preto nem grafite, que somem
## nas fotos); o jogador pode escolher qualquer uma na garagem.
static func cor_do_id(id: String) -> Color:
	var claras := PINTURAS.filter(func(c): return c.get_luminance() > 0.2)
	return claras[posmod(id.hash(), claras.size())]


## Pintura do carro da garagem: a escolhida pelo jogador ou a de fábrica.
static func cor_do_carro(carro: Carro) -> Color:
	return Color.html(carro.cor) if carro.cor != "" else cor_do_id(carro.id)


func _caixa(tam: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = tam
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


static func _cilindro(raio: float, altura: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = raio
	m.bottom_radius = raio
	m.height = altura
	m.radial_segments = 14
	m.rings = 1
	return m


static func _material(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.6
	return m
