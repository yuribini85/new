class_name CarroBloco
extends Node3D
## Placeholder 3D de carro feito de blocos: chassi, cabine e rodas. Comprido
## no eixo +X local (o rumo da pista gira em Y). As proporções seguem a
## categoria do carro; nada de modelo real. A troca por modelo definitivo
## mantém a interface: `configurar(categoria, cor)`.

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
	_caixa(Vector3(comprimento, f["h"], largura), Vector3(0, base_y + f["h"] * 0.5, 0), pintura)
	var cab_c: float = comprimento * f["cab"]
	var vidro := _material(cor.darkened(0.6))
	_caixa(Vector3(cab_c, f["hc"], largura * 0.86),
			Vector3(comprimento * f["recuo"], base_y + f["h"] + f["hc"] * 0.5, 0),
			vidro if f["teto"] else _material(Color(0.15, 0.15, 0.17)))
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
