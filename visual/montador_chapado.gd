class_name MontadorChapado
extends MontadorPista
## Estilo chapado (teste de direção de arte, docs/arte_pistas.md): o mesmo
## traçado e as mesmas regras de composição do MontadorPista, mas sem arte
## pintada. Chão em cores lisas que apagam até o preto longe da pista, pista e
## zebras em cor sólida, árvores e prédios como volumes facetados (cada face uma
## cor, clara do lado da luz), poças de luz quente nos postes e nos boxes.
## Inspiração: ilhas de luz no escuro, poucas cores por lugar.

## Cores de cada superfície (antes da tinta do tema).
const CORES := {
	"asfalto": Color(0.2, 0.2, 0.22), "escape": Color(0.24, 0.31, 0.21), "areia": Color(0.6, 0.5, 0.36),
	"brita": Color(0.46, 0.44, 0.4), "concreto": Color(0.33, 0.33, 0.35), "agua": Color(0.08, 0.13, 0.16),
	"grama_a": Color(0.3, 0.37, 0.22), "grama_b": Color(0.26, 0.32, 0.2), "mata": Color(0.12, 0.16, 0.11),
}
const COR_VAZIO := Color(0.015, 0.02, 0.025)
const COR_ARVORE := [Color(0.2, 0.3, 0.17), Color(0.17, 0.26, 0.16), Color(0.23, 0.31, 0.16)]

static var _shader_chapado: Shader
static var _texturas := {}


func montar(cena: Node3D, pista: Pista, tema: Dictionary, largura: float) -> void:
	_borda_irregular = 0.0
	super(cena, pista, tema, largura)


## Superfícies: o mesmo material do kit, com uma textura de cor lisa.
func _mat(nome: String, metros: float, alfa := false, nome_b := "") -> ShaderMaterial:
	var m := super(nome, metros, alfa, "")
	m.set_shader_parameter("usar_b", 0.0)
	m.set_shader_parameter("borda_seca", 1.0)
	m.set_shader_parameter("textura", _zebra() if nome == "zebra" else _lisa(CORES.get(nome, Color(0.4, 0.4, 0.4))))
	return m


static func _lisa(c: Color) -> ImageTexture:
	var chave := c.to_html()
	if not _texturas.has(chave):
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(c)
		_texturas[chave] = ImageTexture.create_from_image(img)
	return _texturas[chave]


static func _zebra() -> ImageTexture:
	if not _texturas.has("zebra"):
		var img := Image.create(4, 16, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(0, 0, 4, 8), Color(0.66, 0.17, 0.14))
		img.fill_rect(Rect2i(0, 8, 4, 8), Color(0.86, 0.85, 0.8))
		_texturas["zebra"] = ImageTexture.create_from_image(img)
	return _texturas["zebra"]


## Chão: uma imagem só, pintada pela distância à pista. Grama perto, chão de
## mata nas zonas de floresta, apagando até o preto longe; manchas grandes de
## duas cores (planos chapados, sem textura).
func _chao(caixa: Rect2, k: Dictionary) -> void:
	var img := Image.create(_campo_tam.x, _campo_tam.y, false, Image.FORMAT_RGBA8)
	for y in _campo_tam.y:
		for x in _campo_tam.x:
			var p := _campo_origem + Vector2(x, y) * _campo_m
			var d := _campo[y * _campo_tam.x + x]
			var mancha := _clareira.get_noise_2d(p.x * 1.7, p.y * 1.7) > 0.08
			var c: Color = CORES["grama_a"] if mancha else CORES["grama_b"]
			c = c.lerp(CORES["mata"], smoothstep(0.2, 0.6, _floresta(p, d + 12.0)))
			var agua := _agua(p, d)
			if agua > 0.5:
				c = CORES["agua"]
			c = COR_VAZIO.lerp(c, _claridade(d))
			img.set_pixel(x, y, c)
	# Linha 0 da imagem é o y mínimo do mapa, que no mundo é o +z (borda de
	# baixo do PlaneMesh): vira na vertical para casar com a UV do plano.
	img.flip_y()
	var mi := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(_campo_tam) * _campo_m
	mi.mesh = plano
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(_tema.get("tinta", Color.WHITE))
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mi.material_override = m
	var c0 := _campo_origem - Vector2.ONE * _campo_m * 0.5 + plano.size * 0.5
	mi.position = Vector3(c0.x, -0.06, -c0.y)
	_cena.add_child(mi)


func _material(c: Color) -> ShaderMaterial:
	if _shader_chapado == null:
		_shader_chapado = preload("res://visual/shaders/chapado.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader_chapado
	m.set_shader_parameter("cor", c)
	m.set_shader_parameter("tinta", _tema.get("tinta", Color.WHITE))
	var sd: Vector2 = _tema.get("sombra_dir", Vector2(1.0, -0.6))
	# A luz vem do lado oposto ao da sombra (2D: y do mapa é -z do mundo).
	m.set_shader_parameter("luz", Vector3(-sd.x, 2.0, sd.y))
	return m


func _brilhante(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


## Árvores: copas facetadas (esfera de poucos lados, achatada).
func _mata_desenho(nome: String, t: Texture2D, lista: Array, cores: Array) -> void:
	var raio := maxf(t.get_width(), t.get_height()) / PX_M * 0.4
	var esfera := SphereMesh.new()
	esfera.radius = raio
	esfera.height = raio * 1.6
	esfera.radial_segments = 7
	esfera.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = esfera
	mm.instance_count = lista.size()
	var cor_base: Color = COR_ARVORE[hash(nome) % COR_ARVORE.size()]
	if nome.begins_with("rocha"):
		cor_base = Color(0.45, 0.43, 0.4)
	for i in lista.size():
		var tr: Transform3D = lista[i]
		tr.origin.y = raio * 0.3
		mm.set_instance_transform(i, tr)
		mm.set_instance_color(i, cores[i] if i < cores.size() else Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material(cor_base)
	_cena.add_child(mmi)


## Objetos: volumes no lugar dos sprites (mesma planta, altura e cor por tipo).
func _desenho_objeto(nome: String, t: Texture2D, p: Vector2, rumo: float, y: float) -> void:
	var planta := Vector2(t.get_width(), t.get_height()) / PX_M
	var no := Node3D.new()
	no.position = _v3(p, 0.0)
	no.rotation.y = rumo
	_cena.add_child(no)
	if nome == "poste":
		_volume(no, Vector3(0.4, 8.0, 0.4), Vector3.ZERO, Color(0.25, 0.25, 0.27))
		var lampada := MeshInstance3D.new()
		var b := SphereMesh.new()
		b.radius = 0.7
		b.height = 1.4
		lampada.mesh = b
		lampada.material_override = _brilhante(Color(1.0, 0.86, 0.6))
		lampada.position.y = 8.2
		no.add_child(lampada)
		return
	if nome == "box_modulo":
		_volume(no, Vector3(planta.x, 5.0, planta.y * 0.9), Vector3(0, 0, -planta.y * 0.05), Color(0.62, 0.62, 0.64))
		# Porta acesa na frente (borda de baixo do sprite = +z).
		var porta := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(planta.x * 0.82, 0.4, 0.5)
		porta.mesh = bm
		porta.material_override = _brilhante(Color(1.0, 0.72, 0.36))
		porta.position = Vector3(0, 5.05, planta.y * 0.42)
		no.add_child(porta)
		return
	var cfg: Dictionary = {
		"arquibancada_modulo": {"h": 6.0, "cor": Color(0.3, 0.32, 0.38)},
		"torre": {"h": 14.0, "cor": Color(0.66, 0.66, 0.68)},
		"portico": {"h": 1.2, "cor": Color(0.5, 0.5, 0.52), "y": 6.0},
		"tenda_1": {"h": 3.0, "cor": Color(0.82, 0.82, 0.84)},
		"tenda_2": {"h": 3.0, "cor": Color(0.8, 0.8, 0.82)},
		"conteiner_1": {"h": 2.6, "cor": Color(0.6, 0.22, 0.16)},
		"conteiner_2": {"h": 2.6, "cor": Color(0.18, 0.33, 0.5)},
		"conteiner_3": {"h": 2.6, "cor": Color(0.7, 0.55, 0.18)},
	}.get(nome, {})
	if nome.begins_with("caminhao"):
		var cabine: Color = {"caminhao_1": Color(0.66, 0.16, 0.12), "caminhao_2": Color(0.18, 0.28, 0.55)}.get(nome, Color(0.25, 0.25, 0.27))
		_volume(no, Vector3(planta.x, 3.6, planta.y - 2.6), Vector3(0, 0, 1.3), Color(0.85, 0.85, 0.86))
		_volume(no, Vector3(planta.x, 3.0, 2.4), Vector3(0, 0, -planta.y * 0.5 + 1.2), cabine)
		return
	if cfg.is_empty():
		cfg = {"h": 2.0, "cor": Color(0.5, 0.5, 0.52)}
	_volume(no, Vector3(planta.x, cfg["h"], planta.y), Vector3(0, cfg.get("y", 0.0), 0), cfg["cor"])


func _volume(pai: Node3D, tam: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = _material(c)
	mi.position = pos + Vector3(0, tam.y * 0.5, 0)
	pai.add_child(mi)
