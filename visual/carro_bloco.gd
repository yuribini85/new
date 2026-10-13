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
const SHADER_LATARIA := preload("res://visual/shaders/carro_faixas.gdshader")
const SHADER_GLB := preload("res://visual/shaders/carro_glb.gdshader")
## Algarismos de cada família do número (PinturaCarro.FONTES).
const DIGITOS := {"condensado": preload("res://arte/ui/pintura/digitos_condensado.png"),
		"bloco": preload("res://arte/ui/pintura/digitos_bloco.png"),
		"estencil": preload("res://arte/ui/pintura/digitos_estencil.png"),
		"pincel": preload("res://arte/ui/pintura/digitos_pincel.png"),
		"serifa": preload("res://arte/ui/pintura/digitos_serifa.png")}
static var _logos := {}
const FORMAS := {
	"compacto": {"c": 3.75, "l": 1.66, "h": 0.6, "cab": 0.62, "hc": 0.72, "recuo": -0.17, "teto": true},
	"seda": {"c": 4.6, "l": 1.76, "h": 0.6, "cab": 0.44, "hc": 0.6, "recuo": -0.04, "teto": true},
	"cupe": {"c": 4.35, "l": 1.74, "h": 0.52, "cab": 0.4, "hc": 0.46, "recuo": -0.14, "teto": true},
	"roadster": {"c": 4.0, "l": 1.72, "h": 0.52, "cab": 0.22, "hc": 0.32, "recuo": -0.06, "teto": false},
}
const RAIO_RODA := 0.33
## Os três carros iniciais desenhados à mão (só visual): cada um precisa ser
## reconhecido de longe e dar vontade de escolher.
const DESENHOS := {
	"hayase_tsubame": {"hc": 0.76, "cab": 0.66, "recuo": -0.16, "queda_bico": 0.04, "asa": "teto", "raios": 4,
		"cor_aro": Color(0.3, 0.31, 0.34), "aro": 0.66, "lama": 0.03, "farol": "fino"},
	"hayase_pika": {"hc": 0.64, "cab": 0.6, "recuo": -0.18, "queda_bico": 0.12, "asa": "teto", "raios": 5,
		"cor_aro": Color(0.92, 0.92, 0.94), "aro": 0.7, "lama": 0.075, "largura_pneu": 0.28, "roda_mult": 1.05},
	"hayase_soryu": {"hc": 0.43, "cab": 0.36, "recuo": -0.2, "queda_bico": 0.2, "asa": "aerofolio", "raios": 6,
		"cor_aro": Color(0.45, 0.46, 0.5), "aro": 0.68, "lama": 0.05, "farol": "escamoteavel", "cunha": 0.04},
	# Os outros modelos marcantes, para cada um ter cara própria no Mercado.
	"hayase_kobo": {"c": 3.25, "hc": 0.82, "cab": 0.7, "recuo": -0.13, "queda_bico": 0.06, "raios": 4,
		"cor_aro": Color(0.6, 0.62, 0.66), "aro": 0.5, "asa": "nenhuma"},
	"ashcombe_wren": {"c": 3.15, "hc": 0.74, "cab": 0.64, "recuo": -0.15, "queda_bico": 0.1, "asa": "nenhuma"},
	"hayase_kaze": {"c": 3.7, "cab": 0.2, "hc": 0.3, "farol": "redondo", "raios": 6, "aro": 0.6, "queda_bico": 0.18},
	"ashcombe_kestrel": {"c": 3.45, "h": 0.46, "cab": 0.18, "hc": 0.26, "recuo": 0.06, "queda_bico": 0.16},
	"hayase_rin": {"cunha": 0.12, "queda_bico": 0.03, "hc": 0.5, "cab": 0.42, "raios": 4},
	"hayase_shiden": {"recuo": 0.06, "cab": 0.36, "hc": 0.4, "queda_bico": 0.24, "cunha": 0.06},
	"hartwig_strecke": {"c": 4.85, "cab": 0.42, "recuo": -0.05, "hc": 0.58},
	"hartwig_gleiter": {"recuo": -0.2, "cab": 0.36, "hc": 0.46, "queda_bico": 0.16, "asa": "labio"},
	"hartwig_lauf": {"hc": 0.8, "cab": 0.66, "recuo": -0.14, "queda_bico": 0.08},
}
const PINTURAS := [
	Color(0.85, 0.12, 0.12), Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.14), Color(0.15, 0.35, 0.8),
	Color(0.98, 0.78, 0.1), Color(0.2, 0.6, 0.3), Color(0.6, 0.62, 0.66), Color(0.95, 0.45, 0.1),
]

## Modelos 3D prontos (GLB, um por carro: <id>.glb): têm prioridade sobre
## os sprites e o carro em código. Frente em +Z e chão em y = 0 no arquivo.
const PASTA_GLB := "res://arte/carros3d/"

var comprimento := 4.5
var largura := 1.8
var _rodas: Array = []
## Rodas do modelo GLB (nós roda_* ou Mount_* da frota 360): giram no eixo X
## do arquivo; [nó, raio].
var _rodas_glb: Array = []
## Blindagem montada (<id>_protecao.glb, decisão 80): região (front, rear,
## left, right) -> nó Protection_<região>; as camadas Level1..3 são cumulativas.
var _protecao := {}
var _protecao_raiz: Node3D
var _modelo: Node3D


static func tem_glb(id: String) -> bool:
	return id != "" and ResourceLoader.exists(PASTA_GLB + id + ".glb")


## Silhueta só pela categoria (usado onde não há modelo).
func configurar(categoria: String, cor: Color) -> CarroBloco:
	return configurar_modelo({"id": categoria, "categoria": categoria}, cor)


## Silhueta da categoria com o desenho do modelo (ver forma()). `faixas`:
## pintura personalizada da Oficina ({padrao, faixa, filete}; ver PinturaCarro),
## só nos modelos 3D.
func configurar_modelo(base: Dictionary, cor: Color, faixas: Dictionary = {}) -> CarroBloco:
	for c in get_children():
		c.queue_free()
	_rodas = []
	_rodas_glb = []
	if tem_glb(String(base.get("id", ""))):
		return _glb(String(base["id"]), cor, faixas)
	var f := forma(base)
	comprimento = f["c"]
	largura = f["l"]
	var r: float = f["roda"]
	var corpo := MeshInstance3D.new()
	corpo.mesh = carroceria(f, cor)
	add_child(corpo)
	var c := comprimento
	var l := largura
	var cint_frente := cintura_em(f, c * 0.45)
	# Altura do bico (o capô cai até ele): faróis e grade ficam abaixo disto.
	var bico: float = perfil(f, c * 0.47)[0]
	var cint_tras := cintura_em(f, -c * 0.45)
	var escuro := _material(Color(0.06, 0.06, 0.07))
	var aro := _material(f["cor_aro"])
	aro.metallic = 0.6
	aro.roughness = 0.4
	var cromado := _material(Color(0.72, 0.74, 0.78))
	cromado.metallic = 0.6
	cromado.roughness = 0.35
	var pintura := _material(cor)
	# Grade: larga com moldura (Hartwig), fenda fina (Hayase), redonda (Ashcombe).
	match f["grade"]:
		"larga":
			_caixa(Vector3(0.05, 0.2, l * 0.56), Vector3(c * 0.5 + 0.005, bico - 0.2, 0), cromado)
			_caixa(Vector3(0.06, 0.15, l * 0.5), Vector3(c * 0.5 + 0.01, bico - 0.2, 0), escuro)
		"redonda":
			_cilindro_em(0.12, 0.05, Vector3(c * 0.5 + 0.005, bico - 0.22, 0), escuro, Vector3(0, 0, PI / 2.0))
		_:
			_caixa(Vector3(0.05, 0.08, l * 0.44), Vector3(c * 0.5 + 0.005, bico - 0.22, 0), escuro)
	# Faróis: escamoteáveis (anos 80, fechados: só uma linha), redondos ou finos.
	var farol := _material(Color(1.0, 0.97, 0.85))
	farol.emission_enabled = true
	farol.emission = Color(1.0, 0.95, 0.8) * 0.35
	var lanterna := _material(Color(0.8, 0.07, 0.07))
	lanterna.emission_enabled = true
	lanterna.emission = Color(0.5, 0.02, 0.02)
	for z in [-1.0, 1.0]:
		match f["farol"]:
			"escamoteavel":
				_caixa(Vector3(0.3, 0.03, 0.42), Vector3(c * 0.42, perfil(f, c * 0.42)[0] + 0.005, z * l * 0.3), escuro)
			"redondo":
				_cilindro_em(0.12, 0.04, Vector3(c * 0.5 - 0.01, bico - 0.11, z * l * 0.32), cromado, Vector3(0, 0, PI / 2.0))
				_cilindro_em(0.1, 0.05, Vector3(c * 0.5, bico - 0.11, z * l * 0.32), farol, Vector3(0, 0, PI / 2.0))
			_:
				_caixa(Vector3(0.04, 0.13, 0.42), Vector3(c * 0.5 - 0.02, bico - 0.08, z * l * 0.31), cromado)
				_caixa(Vector3(0.05, 0.09, 0.36), Vector3(c * 0.5 - 0.005, bico - 0.08, z * l * 0.31), farol)
		_caixa(Vector3(0.05, 0.11 if f["lanterna_alta"] else 0.08, 0.42), Vector3(-c * 0.5 + 0.01, cint_tras - 0.1, z * l * 0.31), lanterna)
		if f["teto"]:
			var xr: float = c * f["recuo"] + c * f["cab"] * 0.36
			_caixa(Vector3(0.12, 0.08, 0.12), Vector3(xr, cintura_em(f, xr) + 0.06, z * (l * 0.5 + 0.05)), pintura)
		if f["tomadas_laterais"]:
			var xt: float = c * f["recuo"] - c * f["cab"] * 0.55
			_caixa(Vector3(0.45, 0.16, 0.04), Vector3(xt, cintura_em(f, xt) - 0.14, z * l * 0.5), escuro)
		if f["escape_duplo"]:
			_cilindro_em(0.05, 0.12, Vector3(-c * 0.5 - 0.03, 0.26, z * l * 0.22), cromado, Vector3(0, 0, PI / 2.0))
	# Para-choques, placas, coluna central, maçanetas e frisos de porta.
	for ponta in [1.0, -1.0]:
		_caixa(Vector3(0.08, 0.11, l * 0.86), Vector3(ponta * (c * 0.5 + 0.01), 0.27, 0), escuro)
		_caixa(Vector3(0.02, 0.1, 0.32), Vector3(ponta * (c * 0.5 + 0.055), 0.4 if ponta > 0 else cint_tras - 0.28, 0),
				_material(Color(0.92, 0.92, 0.88)))
	if f["teto"]:
		var xb: float = c * f["recuo"] + c * f["cab"] * 0.05
		var yb: float = cintura_em(f, xb)
		for z in [-1.0, 1.0]:
			# Coluna central acompanhando o vidro, que estreita para cima.
			_caixa(Vector3(0.15, f["hc"] * 0.82, 0.05), Vector3(xb, yb + f["hc"] * 0.41, z * l * 0.44), pintura)
			_caixa(Vector3(0.012, yb - 0.24, 0.02), Vector3(xb + 0.02, (yb + 0.2) * 0.5 + 0.02, z * l * 0.505), escuro)
			_caixa(Vector3(0.14, 0.035, 0.02), Vector3(xb - 0.25, yb - 0.12, z * l * 0.507), escuro)
	if f["teto"]:
		var lc: float = c * f["cab"]
		var xcab: float = c * f["recuo"]
		for z in [-1.0, 1.0]:
			_caixa(Vector3(lc, 0.035, 0.02), Vector3(xcab, cintura_em(f, xcab) + 0.01, z * l * 0.468), escuro)
	# Tomada de ar no capô (rali, muscle).
	if f["tomada_capo"]:
		var xc: float = c * f["recuo"] + c * f["cab"] * 0.5 + c * 0.1
		_caixa(Vector3(0.5, 0.08, l * 0.32), Vector3(xc, cintura_em(f, xc) + 0.03, 0), escuro)
	match f["asa"]:
		"grande":
			_caixa(Vector3(0.32, 0.05, l * 0.98), Vector3(-c * 0.46, cint_tras + 0.34, 0), pintura)
			for z in [-1.0, 1.0]:
				_caixa(Vector3(0.1, 0.32, 0.05), Vector3(-c * 0.46, cint_tras + 0.17, z * l * 0.3), escuro)
		"aerofolio":
			_caixa(Vector3(0.26, 0.05, l * 0.9), Vector3(-c * 0.47, cint_tras + 0.2, 0), pintura)
			for z in [-1.0, 1.0]:
				_caixa(Vector3(0.08, 0.18, 0.05), Vector3(-c * 0.47, cint_tras + 0.09, z * l * 0.3), escuro)
		"labio":
			_caixa(Vector3(0.16, 0.05, l * 0.86), Vector3(-c * 0.48, cint_tras + 0.03, 0), pintura)
		"teto":
			var xt: float = c * f["recuo"] - c * f["cab"] * 0.5
			_caixa(Vector3(0.18, 0.04, l * 0.8), Vector3(xt - 0.02, cintura_em(f, xt) + f["hc"] - 0.02, 0), pintura)
	if f["estilo"] == "esportivo":
		_caixa(Vector3(0.08, 0.36, l * 0.6), Vector3(-c * 0.12, cintura_em(f, -c * 0.12) + 0.18, 0), escuro)
	# Rodas: pneu, aro na cor do modelo e raios; traseiras maiores no muscle.
	var pneu := _material(Color(0.11, 0.11, 0.12))
	var lateral := _material(Color(0.2, 0.2, 0.22))
	var cubo := _material(Color(0.15, 0.15, 0.17))
	var entre: float = c * f["entre_eixos"] * 0.5
	var desloc: float = c * f.get("eixos_desloc", 0.0)
	for x in [-entre + desloc, entre + desloc]:
		var rr: float = r * (f["roda_tras"] if x < desloc else 1.0)
		for z in [-1.0, 1.0]:
			var caixa_roda := MeshInstance3D.new()
			caixa_roda.mesh = _cilindro(rr + 0.06, 0.3)
			caixa_roda.material_override = escuro
			caixa_roda.rotation = Vector3(PI / 2.0, 0, 0)
			caixa_roda.position = Vector3(x, rr + 0.02, z * (l * 0.5 - 0.13))
			add_child(caixa_roda)
			var roda := Node3D.new()
			roda.position = Vector3(x, rr, z * (l * 0.5 - 0.1 + f["largura_pneu"] * 0.5 - 0.12))
			add_child(roda)
			var p := MeshInstance3D.new()
			p.mesh = _cilindro(rr, f["largura_pneu"])
			p.material_override = pneu
			p.rotation = Vector3(PI / 2.0, 0, 0)
			roda.add_child(p)
			var flanco := MeshInstance3D.new()
			flanco.mesh = _cilindro(rr * 0.92, 0.02)
			flanco.material_override = lateral
			flanco.rotation = Vector3(PI / 2.0, 0, 0)
			flanco.position.z = z * (f["largura_pneu"] * 0.5 + 0.002)
			roda.add_child(flanco)
			var disco := MeshInstance3D.new()
			disco.mesh = _cilindro(rr * minf(f["aro"] + 0.06, 0.8), 0.02)
			disco.material_override = aro
			disco.rotation = Vector3(PI / 2.0, 0, 0)
			disco.position.z = z * (f["largura_pneu"] * 0.5 + 0.005)
			roda.add_child(disco)
			var centro := MeshInstance3D.new()
			centro.mesh = _cilindro(rr * 0.16, 0.03)
			centro.material_override = cubo
			centro.rotation = Vector3(PI / 2.0, 0, 0)
			centro.position.z = z * (f["largura_pneu"] * 0.5 + 0.02)
			roda.add_child(centro)
			for k in int(f["raios"]):
				var raio := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(rr * f["aro"] * 1.9, 0.05, 0.02)
				raio.mesh = b
				raio.material_override = escuro
				raio.position.z = z * (f["largura_pneu"] * 0.5 + 0.017)
				raio.rotation.z = PI * k / float(f["raios"])
				roda.add_child(raio)
			_rodas.append(roda)
	_sombra(c, l)
	return self


func _sombra(c: float, l: float, alfa := 0.45) -> void:
	var sombra := MeshInstance3D.new()
	sombra.name = "Sombra"
	var q := PlaneMesh.new()
	q.size = Vector2(c * 1.05, l * 1.15)
	sombra.mesh = q
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0, 0, 0, alfa)
	ms.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ms.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sombra.material_override = ms
	sombra.position.y = 0.02
	add_child(sombra)


## Pintura do modelo GLB. Material "Paint" (textura branca): só ele recebe a
## cor; os outros ficam como vieram (desenhados dos dois lados, como o atlas).
## Sem "Paint": atlas de cores, a lataria clara pintada pelo shader.
static func _pintar_glb(mi: MeshInstance3D, cor: Color, faixas: Dictionary = {}) -> void:
	var tem_paint := false
	for i in mi.get_surface_override_material_count():
		var m := mi.get_active_material(i)
		if m != null and m.resource_name.to_lower() == "paint":
			tem_paint = true
	if tem_paint:
		for i in mi.get_surface_override_material_count():
			var m := mi.get_active_material(i)
			if not m is BaseMaterial3D:
				continue
			var nova := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			nova.cull_mode = BaseMaterial3D.CULL_DISABLED
			if m.resource_name.to_lower() == "paint":
				# Sempre o shader da lataria: faixas, número e acabamento mudam
				# só os parâmetros (repintar), sem recarregar o modelo.
				var sm := ShaderMaterial.new()
				sm.shader = SHADER_LATARIA
				sm.set_shader_parameter("cor_base", cor)
				_parametros_faixas(sm, mi, faixas)
				mi.set_surface_override_material(i, sm)
				continue
			mi.set_surface_override_material(i, nova)
		return
	var atlas: Texture2D = null
	var original := mi.get_active_material(0)
	if original is BaseMaterial3D:
		atlas = (original as BaseMaterial3D).albedo_texture
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_GLB
	mat.set_shader_parameter("atlas", atlas)
	mat.set_shader_parameter("pintura", cor)
	_parametros_faixas(mat, mi, faixas)
	mi.material_override = mat


## Faixas da Oficina nos uniforms do shader (faixas.gdshaderinc).
static func _parametros_faixas(sm: ShaderMaterial, mi: MeshInstance3D, faixas: Dictionary) -> void:
	var caixa := mi.get_aabb()
	sm.set_shader_parameter("cor_faixa", Color(String(faixas.get("faixa", "#ffffff"))))
	sm.set_shader_parameter("cor_filete", Color(String(faixas.get("filete", "#1a1a1a"))))
	sm.set_shader_parameter("padrao", PinturaCarro.indice_padrao(String(faixas.get("padrao", ""))))
	sm.set_shader_parameter("caixa_min", caixa.position)
	sm.set_shader_parameter("caixa_tam", caixa.size)
	sm.set_shader_parameter("digitos", DIGITOS.get(String(faixas.get("fonte_numero", "condensado")), DIGITOS["condensado"]))
	sm.set_shader_parameter("escala_numero", float(faixas.get("escala_numero", 1.0)))
	sm.set_shader_parameter("suporte_numero", bool(faixas.get("suporte_numero", false)))
	var logo := _logo(faixas)
	sm.set_shader_parameter("logo", logo)
	sm.set_shader_parameter("locais_logo", int(faixas.get("locais_logo", 0)) if logo != null else 0)
	sm.set_shader_parameter("escala_logo", float(faixas.get("escala_logo", 1.0)))
	sm.set_shader_parameter("largura_faixas", float(faixas.get("largura", 1.0)))
	sm.set_shader_parameter("espelhar", bool(faixas.get("espelhar", false)))
	sm.set_shader_parameter("poeira", float(faixas.get("poeira", 0.0)))
	sm.set_shader_parameter("arranhoes", float(faixas.get("arranhoes", 0.0)))
	sm.set_shader_parameter("numero", int(faixas.get("numero", -1)))
	sm.set_shader_parameter("locais_numero", int(faixas.get("locais_numero", PinturaCarro.LOCAIS_PADRAO)))
	sm.set_shader_parameter("cor_numero", Color(String(faixas.get("cor_numero", "#141518"))))
	sm.set_shader_parameter("cor_contorno", Color(String(faixas.get("cor_contorno", "#f2f2ee"))))
	sm.set_shader_parameter("acabamento", PinturaCarro.indice_acabamento(String(faixas.get("acabamento", ""))))


## Textura do logo da pintura: o da equipe rival (faixas.logo) ou, nos carros
## do jogador, o emblema da equipe dele (IdentidadeEquipe); null sem logo.
static func _logo(faixas: Dictionary) -> Texture2D:
	if int(faixas.get("locais_logo", 0)) == 0:
		return null
	var caminho := String(faixas.get("logo", ""))
	if caminho == "":
		var j: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Jogador") \
				if Engine.get_main_loop() is SceneTree else null
		if j != null:
			caminho = IdentidadeEquipe.arquivo_logo(IdentidadeEquipe.logo(j))
	if caminho == "" or not ResourceLoader.exists(caminho):
		return null
	if not _logos.has(caminho):
		_logos[caminho] = load(caminho)
	return _logos[caminho]


## Troca a pintura do modelo já montado (cabine de pintura): só os parâmetros
## dos shaders da lataria, sem recarregar o GLB.
func repintar(cor: Color, faixas: Dictionary) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var mats: Array = [mi.material_override]
		for i in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(i))
		for m in mats:
			if not m is ShaderMaterial:
				continue
			var sm := m as ShaderMaterial
			if sm.shader == SHADER_LATARIA:
				sm.set_shader_parameter("cor_base", cor)
			elif sm.shader == SHADER_GLB:
				sm.set_shader_parameter("pintura", cor)
			else:
				continue
			_parametros_faixas(sm, mi, faixas)


## Modelo GLB: girado para a frente em +X, lataria pintada (_pintar_glb).
func _glb(id: String, cor: Color, faixas: Dictionary = {}) -> CarroBloco:
	var cena: PackedScene = load(PASTA_GLB + id + ".glb")
	var modelo: Node3D = cena.instantiate()
	modelo.rotation.y = PI / 2.0  # +Z do arquivo -> +X do jogo
	add_child(modelo)
	var caixa := AABB()
	var primeiro := true
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		_pintar_glb(mi, cor, faixas)
		var b := mi.get_aabb()
		caixa = b if primeiro else caixa.merge(b)
		primeiro = false
	comprimento = caixa.size.z
	largura = caixa.size.x
	_modelo = modelo
	var rodas: Array = modelo.find_children("roda_*", "Node3D", true, false)
	# Frota 360: Mount_<posição> é a roda, com o centro no eixo; os nós
	# Mount_*_Wheel_Details são a malha dela (filhos ou irmãos).
	for no: Node3D in modelo.find_children("Mount_*", "Node3D", true, false):
		if not String(no.name).contains("_Wheel"):
			rodas.append(no)
	for no: Node3D in rodas:
		var raio := 0.3
		for mi: MeshInstance3D in ([no] if no is MeshInstance3D else []) + no.find_children("*", "MeshInstance3D", true, false):
			raio = mi.get_aabb().size.y * 0.5
		_rodas_glb.append([no, maxf(raio, 0.1)])
	_sombra(comprimento * 0.92, largura * 0.78, 0.3)
	return self


## Blindagem visual (decisão 80): monta as proteções do modelo até o nível
## (0 tira). Só nos modelos que trazem <id>_protecao.glb.
func blindar(id: String, nivel: int) -> void:
	if is_instance_valid(_protecao_raiz):
		_protecao_raiz.queue_free()
	_protecao = {}
	var caminho := PASTA_GLB + id + "_protecao.glb"
	if nivel <= 0 or _modelo == null or not ResourceLoader.exists(caminho):
		return
	var p: Node3D = (load(caminho) as PackedScene).instantiate()
	_modelo.add_child(p)
	_protecao_raiz = p
	for regiao in ["front", "rear", "left", "right"]:
		var no := p.find_child("Protection_" + regiao, true, false) as Node3D
		if no == null:
			continue
		_protecao[regiao] = no
		for camada in no.get_children():
			var k := String(camada.name).find("Level")
			if k >= 0:
				(camada as Node3D).visible = int(String(camada.name)[k + 5]) <= nivel
	# Placas em metal claro e gasto, com rebites (pedido do usuário: o
	# material do modelo, escuro, sumia na carroceria e no chão).
	for mi: MeshInstance3D in p.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _metal_placa()


static var _placa: StandardMaterial3D


## Chapa de aço clara: manchas e riscos de uso e uma fileira de rebites a
## cada 0,25 m, projetada no espaço do objeto (os UVs do modelo não importam).
static func _metal_placa() -> StandardMaterial3D:
	if _placa != null:
		return _placa
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 41
	ruido.frequency = 0.06
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for y in n:
		for x in n:
			var v := 0.78 + 0.12 * ruido.get_noise_2d(x, y)
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.95))
	# Riscos finos (arrastos de batida).
	for k in 26:
		var a := Vector2(rng.randf() * n, rng.randf() * n)
		var d := Vector2.from_angle(rng.randf_range(-0.4, 0.4)) * rng.randf_range(10, 40)
		for t in 40:
			var q := (a + d * t / 40.0).posmod(n)
			var c := img.get_pixelv(Vector2i(q))
			img.set_pixelv(Vector2i(q), c.lightened(0.18) if k % 2 == 0 else c.darkened(0.25))
	# Rebites nos cantos de cada quadro.
	for cy in [8, 72]:
		for cx in [8, 72]:
			for yy in range(-3, 4):
				for xx in range(-3, 4):
					var r := Vector2(xx, yy).length()
					if r <= 3.0:
						var q := Vector2i((cx + xx) % n, (cy + yy) % n)
						img.set_pixelv(q, Color(0.45, 0.44, 0.42) if r > 2.0 else Color(0.95, 0.94, 0.9))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 2.0  # um quadro de 0,5 m (rebites a cada 0,25 m)
	m.metallic = 0.55
	m.roughness = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_placa = m
	return m


## Proteção montada numa região (front, rear, left, right), ou null.
func protecao(regiao: String) -> Node3D:
	var no: Node3D = _protecao.get(regiao)
	return no if no != null and is_instance_valid(no) and no.is_inside_tree() else null


## Solta a proteção da região: sai do carro e fica no mundo onde estava
## (quem mostra anima a queda). Devolve o nó solto ou null.
func soltar_protecao(regiao: String, mundo: Node3D) -> Node3D:
	var no := protecao(regiao)
	if no == null:
		return null
	_protecao.erase(regiao)
	var t := no.global_transform
	no.get_parent().remove_child(no)
	mundo.add_child(no)
	no.global_transform = t
	return no


## Explosão (pacote de dano): as rodas saem do carro para o `mundo` (com a
## malha delas, filha ou irmã) e são devolvidas para cair.
func soltar_rodas(mundo: Node3D) -> Array:
	var soltas := []
	for r in _rodas_glb:
		var no: Node3D = r[0]
		var grupo: Array = [no]
		if no.get_parent() != null:
			for irmao in no.get_parent().get_children():
				if irmao != no and irmao is Node3D and String(irmao.name).begins_with(String(no.name) + "_Wheel"):
					grupo.append(irmao)
		for n: Node3D in grupo:
			var t := n.global_transform
			n.get_parent().remove_child(n)
			mundo.add_child(n)
			n.global_transform = t
			soltas.append(n)
	_rodas_glb.clear()
	for roda in _rodas:
		var t: Transform3D = roda.global_transform
		roda.get_parent().remove_child(roda)
		mundo.add_child(roda)
		roda.global_transform = t
		soltas.append(roda)
	_rodas.clear()
	return soltas


## Carcaça chamuscada depois da explosão.
func carbonizar() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(.16, .15, .13)
	m.roughness = 1
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mi.name != "Sombra":
			mi.material_override = m


## Gira as rodas pela distância andada (m).
## Comprimento e largura (m).
func dimensoes() -> Vector2:
	return Vector2(comprimento, largura)


func girar_rodas(distancia: float) -> void:
	for roda in _rodas:
		roda.rotation.z -= distancia / RAIO_RODA
	for r in _rodas_glb:
		(r[0] as Node3D).rotation.x += distancia / float(r[1])


## Desenho do modelo, tirado dos dados dele (sempre o mesmo para o mesmo
## carro): a categoria dá a silhueta; ano, tração, potência, peso e
## fabricante dão proporções e detalhes.
##   anos 80 (até 1990): linhas retas, cunha, faróis escamoteáveis no cupê
##   motor central (MR): cabine avançada, traseira longa, tomadas laterais
##   4x4 forte (>= 260 cv): rali, tomada no capô, asa grande, para-lamas largos
##   tração traseira forte (>= 300 cv): muscle, capô longo, rodas traseiras
##     maiores, escape duplo
##   leve (<= 850 kg): pequeno e estreito, rodas pequenas
static func forma(base: Dictionary) -> Dictionary:
	var cat: String = base.get("categoria", "seda")
	var f: Dictionary = FORMAS.get(cat, FORMAS["seda"]).duplicate()
	f["estilo"] = {"compacto": "hatch", "seda": "seda", "cupe": "cupe", "roadster": "esportivo"}.get(cat, "seda")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(base.get("id", cat)))
	var potencia := float(base.get("potencia", 150.0))
	var peso := float(base.get("peso", 1100.0))
	var ano := int(base.get("ano", 1995))
	var tracao: String = base.get("tracao", "FF")
	var fab: String = base.get("fabricante", "")
	var esportividade := clampf((potencia / maxf(peso, 1.0) - 0.1) / 0.25, 0.0, 1.0)
	var porte := clampf((peso - 700.0) / 800.0, 0.0, 1.0)
	f["c"] = f["c"] * lerpf(0.92, 1.07, porte)
	f["l"] = f["l"] * lerpf(0.94, 1.05, porte)
	if f["estilo"] != "hatch":
		f["hc"] = f["hc"] * lerpf(1.04, 0.86, esportividade)
	f["cab"] = f["cab"] * rng.randf_range(0.96, 1.04)
	f["roda"] = RAIO_RODA * lerpf(0.9, 1.08, esportividade)
	f["roda_tras"] = 1.0
	f["largura_pneu"] = lerpf(0.2, 0.3, esportividade)
	f["aro"] = 0.62
	f["raios"] = 5 if esportividade > 0.5 else (4 if rng.randf() < 0.5 else 6)
	f["entre_eixos"] = rng.randf_range(0.6, 0.65)
	f["eixos_desloc"] = 0.0
	f["queda_bico"] = lerpf(0.1, 0.2, rng.randf())
	f["cunha"] = 0.0
	f["lama"] = 0.035
	f["asa"] = "teto" if f["estilo"] == "hatch" else ("aerofolio" if cat == "cupe" and esportividade > 0.35 else "nenhuma")
	f["farol"] = "fino"
	f["grade"] = "fenda"
	f["tomada_capo"] = false
	f["tomadas_laterais"] = false
	f["escape_duplo"] = false
	f["lanterna_alta"] = false
	f["cor_aro"] = Color(0.72, 0.74, 0.78)
	match fab:
		"hartwig":
			f["grade"] = "larga"
			f["cor_aro"] = Color(0.32, 0.33, 0.36)
			f["lanterna_alta"] = true
			f["raios"] = 10
			f["aro"] = 0.7
		"ashcombe":
			f["grade"] = "redonda"
			f["farol"] = "redondo"
			f["cor_aro"] = Color(0.85, 0.85, 0.82)
			f["raios"] = 8
	if ano <= 1990:
		f["queda_bico"] = 0.05
		f["cunha"] = 0.08
		if cat == "cupe":
			f["farol"] = "escamoteavel"
		f["hc"] *= 1.04
	if tracao == "MR":
		f["recuo"] += 0.14
		f["eixos_desloc"] = -0.02
		f["tomadas_laterais"] = true
		f["queda_bico"] = 0.22
	if tracao == "4WD" and potencia >= 260.0:
		f["tomada_capo"] = true
		f["asa"] = "grande"
		f["lama"] = 0.08
		f["cor_aro"] = Color(0.85, 0.7, 0.25)
		f["largura_pneu"] = 0.3
	if tracao == "FR" and potencia >= 300.0:
		f["recuo"] -= 0.1
		f["tomada_capo"] = true
		f["roda_tras"] = 1.12
		f["escape_duplo"] = true
		f["lama"] = 0.07
		f["asa"] = "labio"
		f["largura_pneu"] = 0.32
	if peso <= 850.0:
		f["c"] *= 0.9
		f["l"] *= 0.92
		f["hc"] *= 1.06
	var desenho: Dictionary = DESENHOS.get(String(base.get("id", "")), {})
	for k in desenho:
		if k == "roda_mult":
			f["roda"] *= desenho[k]
		else:
			f[k] = desenho[k]
		f["roda"] = RAIO_RODA * 0.86
		f["largura_pneu"] = 0.18
	return f


## Altura da cintura em x: na cunha (anos 80) sobe da frente para trás.
static func cintura_em(f: Dictionary, x: float) -> float:
	var t: float = (x + f["c"] * 0.5) / f["c"]
	return f.get("roda", RAIO_RODA) * 0.9 + f["h"] + f.get("cunha", 0.0) * (1.0 - t)


## Altura do topo da carroceria em x (m, do centro) e se ali é vidro.
static func perfil(f: Dictionary, x: float) -> Array:
	var c: float = f["c"]
	var cintura: float = cintura_em(f, x)
	var xc: float = c * f["recuo"]
	var lc: float = c * f["cab"]
	var tras := xc - lc * 0.5
	var frente := xc + lc * 0.5
	var teto: float = cintura_em(f, xc) + f["hc"]
	var t := (x + c * 0.5) / c
	var queda: float = f.get("queda_bico", 0.15)
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
	if f.get("estilo", "") == "seda" and x < tras and t > 0.05:
		return [cintura + 0.1, false]  # porta-malas: o terceiro volume do sedã
	return [topo, false]


## Malha da carroceria: seções ligadas em faixas, sombreamento chapado, vidro
## escuro, para-lamas alargados sobre as rodas.
static func carroceria(f: Dictionary, cor: Color) -> ArrayMesh:
	var c: float = f["c"]
	var l: float = f["l"]
	var r: float = f.get("roda", RAIO_RODA)
	var y0 := 0.18
	var estacoes := 36
	var entre: float = c * f.get("entre_eixos", 0.62) * 0.5
	var desloc: float = c * f.get("eixos_desloc", 0.0)
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
		for ex in [-entre + desloc, entre + desloc]:
			lama = maxf(lama, 1.0 - clampf(absf(x - ex) / (r * 1.6), 0.0, 1.0))
		var lado: float = meia * (1.0 + float(f.get("lama", 0.035)) * lama)
		var cintura := cintura_em(f, x)
		var ombro := minf(topo, cintura)
		var vid: bool = p[1] and topo > cintura + 0.02
		secoes.append([
			Vector3(x, y0, lado * 0.9), Vector3(x, y0 + 0.08, lado), Vector3(x, (y0 + ombro) * 0.5 + 0.05, lado),
			Vector3(x, ombro - 0.02, lado * 0.98), Vector3(x, ombro, lado * 0.93),
			Vector3(x, topo, lado * (0.8 if vid else 0.88)), Vector3(x, topo + (0.015 if vid else 0.0), 0.0),
		])
		vidros.append(vid)
		topos.append(topo)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cor_vidro := Color(0.14, 0.19, 0.27)
	var cor_parabrisa := Color(0.26, 0.33, 0.43)
	for i in estacoes:
		var a: Array = secoes[i]
		var b: Array = secoes[i + 1]
		for k in a.size() - 1:
			var eh_vidro: bool = (k == 4 and (vidros[i] or vidros[i + 1])) or (k == 5 and vidros[i] and vidros[i + 1]
					and absf(float(topos[i]) - float(topos[i + 1])) > 0.01)
			var cor_q := (cor_parabrisa if k == 5 else cor_vidro) if eh_vidro else (Color(0.08, 0.08, 0.09) if k == 0 else (cor.darkened(0.12) if k == 1 else cor))
			for lado in [1.0, -1.0]:
				var q := [a[k], b[k], b[k + 1], a[k + 1]].map(func(v): return Vector3(v.x, v.y, v.z * lado))
				_quad(st, q, cor_q, lado < 0.0)
	for ponta in [0, estacoes]:
		var sec: Array = secoes[ponta]
		# Leque a partir do centro da base: tampa cheia, sem buraco nem bico.
		var centro := Vector3(sec[0].x, sec[0].y, 0.0)
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
	mat.roughness = 0.5
	mat.metallic = 0.0
	mat.metallic_specular = 0.32
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


## Pintura do carro da garagem: a escolhida na compra (Carro.cor) ou a de
## fábrica do modelo (Cores). Sem pintura livre depois, como no GT2.
static func cor_do_carro(carro: Carro) -> Color:
	return Cores.do_carro(carro)


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
	m.roughness = 0.65
	m.metallic_specular = 0.25
	return m


func _cilindro_em(raio: float, altura: float, pos: Vector3, mat: Material, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cilindro(raio, altura)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
