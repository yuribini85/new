class_name MontadorPista
extends RefCounted
## Monta o cenário de uma pista a partir do kit de arte (docs/arte_pistas.md),
## seguindo o traçado exato da simulação. Nenhuma pista é pintada à mão: as
## regras abaixo decidem onde vai cada coisa, e a mesma pista sai sempre igual
## (semente pelo id). Trocar a arte é trocar os arquivos do kit.
##
## Camadas, de baixo para cima: chão (duas texturas em manchas), areia e brita
## por fora das curvas, faixa de escape, asfalto, linhas brancas, zebras; pit
## lane, boxes, arquibancada, torre e pórtico na reta de largada; paddock no
## lado de dentro; postes no pátio dos boxes e no paddock; mata em volta, mais densa longe da pista.
## Sombras dos objetos geradas aqui, na direção da luz do tema.

const PASTA := "res://arte/pistas/kit/"
## Escala do kit (px por metro).
const PX_M := 32.0

## Regras de composição (apresentação, não balanceamento).
const ESCAPE_M := 3.0          # faixa de escape pintada dos dois lados
const ZEBRA_M := 1.2           # largura da zebra, por fora do asfalto
const RAIO_AREIA_M := 90.0     # curva até este raio ganha caixa de areia por fora
const RAIO_BRITA_M := 200.0    # de RAIO_AREIA_M até este, brita
const AREIA_M := 16.0          # largura da caixa de areia
const BRITA_M := 7.0
const MARGEM_M := 240.0        # quanto de cenário em volta do traçado
const MATA_MIN_M := 26.0       # sem árvores mais perto que isto do eixo
const PASSO_ARVORE_M := 7.0
const PASSO_CONTEINER_M := 22.0
const ARVORE_ISOLADA := 0.025  # chance de árvore solta na faixa aberta perto da pista
const FUNDO_ESCURO := 0.3      # quanto as copas escurecem no fundo da mata
const POSTE_A_CADA_M := 40.0
const ALTURA_MATA_M := 4.0
const LUZ_POSTE := Color(1.0, 0.72, 0.38, 0.32)
const LUZ_BOX := Color(1.0, 0.7, 0.35, 0.4)     # altura da sombra das árvores (em unidades de sombra_dir)

static var _cache_tex := {}
static var _shader_alfa: Shader
static var _shader_opaco: Shader
static var _ruido: Texture2D

var _cena: Node3D
var _pista: Pista
var _tema: Dictionary
var _largura: float
var _rng := RandomNumberGenerator.new()
var _grade := {}  # célula -> PackedVector2Array de pontos do eixo
const CELULA_M := 40.0
var _reservas: Array = []
var _clareira: FastNoiseLite
var _borda_irregular := 1.0  # 0 no estilo chapado: bordas retas
# Campo de distância ao eixo numa grade (alcance ilimitado, ao contrário de
# _distancia) e a máscara do chão (R: água, G: chão de floresta), na mesma grade.
var _campo := PackedFloat32Array()
var _campo_origem := Vector2.ZERO
var _campo_m := 4.0
var _campo_tam := Vector2i.ZERO
var _mascara: Image
# Reta de largada: ponto do meio, normal para fora (lado dos boxes) e b0.
var _largada_meio := Vector2.ZERO
var _largada_fora := Vector2.ZERO  # PackedVector2Array: áreas sem árvore (boxes, paddock)


static func kit(nome: String) -> Texture2D:
	if not _cache_tex.has(nome):
		var caminho := PASTA + nome + ".png"
		_cache_tex[nome] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _cache_tex[nome]


## true se o kit existe (sem ele, a corrida usa o cenário antigo).
static func disponivel() -> bool:
	return kit("asfalto") != null and kit("grama_a") != null


func montar(cena: Node3D, pista: Pista, tema: Dictionary, largura: float) -> void:
	_cena = cena
	_pista = pista
	_tema = tema
	_largura = largura
	_rng.seed = hash(pista.id + "montador")
	_indexar_eixo()
	var k: Dictionary = tema["kit"]
	var caixa := _caixa()
	_clareira = FastNoiseLite.new()
	_clareira.seed = hash(pista.id)
	_clareira.frequency = 0.008
	_lado_da_largada()
	_campo_distancia(caixa)
	_mascara_chao(k)
	_chao(caixa, k)
	_bordas_curvas(k)
	_faixa_volta(-(_largura * 0.5 + ESCAPE_M), _largura * 0.5 + ESCAPE_M, -0.03, _mat(k.get("escape", "escape"), 16.0))
	_faixa_volta(-_largura * 0.5, _largura * 0.5, -0.02, _mat("asfalto", 16.0))
	var branco := _cor(Color(0.9, 0.9, 0.88))
	for lado in [-1.0, 1.0]:
		var a: float = lado * (_largura * 0.5 - 0.55)
		_faixa_volta(minf(a, a + lado * 0.3), maxf(a, a + lado * 0.3), -0.015, branco)
	_zebras()
	_reta_de_largada(k)
	_mata(caixa, k)


# --- Geometria ---------------------------------------------------------------

func _indexar_eixo() -> void:
	var s := 0.0
	while s < _pista.comprimento:
		var p := _pista.posicao_em(s)
		var c := Vector2i(floori(p.x / CELULA_M), floori(p.y / CELULA_M))
		if not _grade.has(c):
			_grade[c] = PackedVector2Array()
		_grade[c].append(p)
		s += 4.0


## Distância (m) do ponto ao eixo da pista; INF além de 2 células.
func _distancia(p: Vector2) -> float:
	var c := Vector2i(floori(p.x / CELULA_M), floori(p.y / CELULA_M))
	var melhor := INF
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var lista = _grade.get(c + Vector2i(dx, dy))
			if lista == null:
				continue
			for q in lista:
				melhor = minf(melhor, p.distance_squared_to(q))
	return sqrt(melhor)


func _caixa() -> Rect2:
	var r := Rect2(_pista.posicao_em(0.0), Vector2.ZERO)
	var s := 0.0
	while s < _pista.comprimento:
		r = r.expand(_pista.posicao_em(s))
		s += 10.0
	return r.grow(MARGEM_M)


## Campo de distância ao eixo (chanfro 3x3, duas passadas) na grade da máscara.
func _campo_distancia(caixa: Rect2) -> void:
	_campo_m = maxf(4.0, maxf(caixa.size.x, caixa.size.y) / 300.0)
	_campo_origem = caixa.position
	_campo_tam = Vector2i(ceili(caixa.size.x / _campo_m) + 1, ceili(caixa.size.y / _campo_m) + 1)
	var w := _campo_tam.x
	var h := _campo_tam.y
	_campo.resize(w * h)
	_campo.fill(1e9)
	var s := 0.0
	while s < _pista.comprimento:
		var p := _pista.posicao_em(s)
		var c := Vector2i(((p - _campo_origem) / _campo_m).round())
		if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
			var centro := _campo_origem + Vector2(c) * _campo_m
			_campo[c.y * w + c.x] = minf(_campo[c.y * w + c.x], centro.distance_to(p))
		s += _campo_m * 0.5
	var r := _campo_m
	var dg := _campo_m * 1.41421
	for y in h:
		for x in w:
			var i := y * w + x
			var v := _campo[i]
			if x > 0:
				v = minf(v, _campo[i - 1] + r)
			if y > 0:
				v = minf(v, _campo[i - w] + r)
				if x > 0:
					v = minf(v, _campo[i - w - 1] + dg)
				if x < w - 1:
					v = minf(v, _campo[i - w + 1] + dg)
			_campo[i] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var i := y * w + x
			var v := _campo[i]
			if x < w - 1:
				v = minf(v, _campo[i + 1] + r)
			if y < h - 1:
				v = minf(v, _campo[i + w] + r)
				if x < w - 1:
					v = minf(v, _campo[i + w + 1] + dg)
				if x > 0:
					v = minf(v, _campo[i + w - 1] + dg)
			_campo[i] = v


## Distância ao eixo pelo campo (bilinear); longe da caixa, grande.
func _dist_campo(p: Vector2) -> float:
	var f := (p - _campo_origem) / _campo_m
	var x0 := floori(f.x)
	var y0 := floori(f.y)
	if x0 < 0 or y0 < 0 or x0 >= _campo_tam.x - 1 or y0 >= _campo_tam.y - 1:
		return 1e9
	var tx := f.x - x0
	var ty := f.y - y0
	var w := _campo_tam.x
	var a := lerpf(_campo[y0 * w + x0], _campo[y0 * w + x0 + 1], tx)
	var b := lerpf(_campo[(y0 + 1) * w + x0], _campo[(y0 + 1) * w + x0 + 1], tx)
	return lerpf(a, b, ty)


## Chance de floresta densa no ponto (0..1): faixa aberta perto da pista,
## mata fechada depois dela, com clareiras por ruído. A máscara do chão de
## floresta e o sorteio das árvores usam a mesma conta.
func _floresta(p: Vector2, d: float) -> float:
	var k: Dictionary = _tema["kit"]
	var aberto: float = k.get("aberto_m", MATA_MIN_M)
	return smoothstep(aberto, aberto + 50.0, d) * smoothstep(-0.25, 0.15, _clareira.get_noise_2d(p.x, p.y)) \
			* float(k.get("densidade", 1.0))


## Água (cais): do lado dos boxes, além de uma linha paralela à reta de
## largada, e longe de qualquer trecho do traçado.
func _agua(p: Vector2, d: float) -> float:
	var cfg: Dictionary = _tema["kit"].get("agua", {})
	if cfg.is_empty():
		return 0.0
	var lateral := (p - _largada_meio).dot(_largada_fora)
	var limite := _largura * 0.5 + ESCAPE_M + float(cfg.get("afastamento_m", 80.0))
	return clampf((lateral - limite) / _campo_m + 0.5, 0.0, 1.0) * clampf((d - limite * 0.7) / _campo_m + 0.5, 0.0, 1.0)


func _mascara_chao(k: Dictionary) -> void:
	_mascara = null
	var usar_mata: bool = k.has("chao_mata") and not k.get("alinhado", false)
	if not usar_mata and not k.has("agua") and not _tema.has("escuro"):
		return
	_mascara = Image.create(_campo_tam.x, _campo_tam.y, false, Image.FORMAT_RGBA8)
	for y in _campo_tam.y:
		for x in _campo_tam.x:
			var p := _campo_origem + Vector2(x, y) * _campo_m
			var d := _campo[y * _campo_tam.x + x]
			var agua := _agua(p, d)
			# Chão de floresta um pouco além da borda das árvores.
			var mata := _floresta(p, d + 12.0) if usar_mata else 0.0
			_mascara.set_pixel(x, y, Color(agua, mata * (1.0 - agua), _claridade(d), 1.0))


## Ilhas de luz (direção de arte, docs/arte_pistas.md): perto da pista, claro;
## longe, o mundo apaga até quase preto. 1 = claro, `minimo` = mais escuro.
func _claridade(d: float) -> float:
	var e: Dictionary = _tema.get("escuro", {})
	if e.is_empty():
		return 1.0
	return lerpf(1.0, float(e.get("minimo", 0.12)), smoothstep(float(e.get("perto_m", 60.0)), float(e.get("longe_m", 200.0)), d))


static var _shader_luz: Shader


## Poça de luz no chão (poste, boxes): disco somado, mais forte no centro.
func _luz(p: Vector2, raio: float, cor: Color) -> void:
	if not _tema.has("escuro"):
		return
	if _shader_luz == null:
		_shader_luz = Shader.new()
		_shader_luz.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 cor : source_color;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.8);
	ALBEDO = cor.rgb * a * cor.a;
}
"""
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * raio * 2.0
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader_luz
	m.set_shader_parameter("cor", cor)
	mi.material_override = m
	mi.position = _v3(p, 0.04)
	_cena.add_child(mi)


func _lado_da_largada() -> void:
	var i0 := _pista.indice_em(0.5)
	var reta: Dictionary = _pista.trechos[i0]
	var comp := float(reta["comprimento_m"]) if float(reta.get("raio_m", 0.0)) <= 0.0 else 120.0
	var s_meio: float = _pista.inicios[i0] + comp * 0.5
	var normal := Vector2.from_angle(_pista.rumo_em(s_meio) + PI / 2.0)
	_largada_meio = _pista.posicao_em(s_meio)
	var dentro := 1.0 if (_caixa().get_center() - _largada_meio).dot(normal) > 0.0 else -1.0
	_largada_fora = -normal * dentro


## Ponto deslocado do eixo: lateral > 0 à esquerda do sentido da pista.
func _ponto(s: float, lateral: float) -> Vector2:
	return _pista.posicao_em(s) + Vector2.from_angle(_pista.rumo_em(s) + PI / 2.0) * lateral


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, -p.y)


# --- Materiais ---------------------------------------------------------------

static func _shaders() -> void:
	if _shader_alfa != null:
		return
	_shader_alfa = preload("res://visual/shaders/superficie.gdshader")
	# Versão opaca (sem ALPHA): chão e asfalto não entram na fila de transparência.
	_shader_opaco = Shader.new()
	var codigo := _shader_alfa.code
	codigo = codigo.replace("	if (a < 0.999) {\n		ALPHA = a;\n	}\n", "")
	_shader_opaco.code = codigo
	var n := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.seed = 3
	fn.frequency = 0.02
	n.noise = fn
	n.seamless = true
	n.width = 256
	n.height = 256
	_ruido = n


func _mat(nome: String, metros: float, alfa := false, nome_b := "") -> ShaderMaterial:
	_shaders()
	var m := ShaderMaterial.new()
	m.shader = _shader_alfa if alfa else _shader_opaco
	m.set_shader_parameter("textura", kit(nome))
	m.set_shader_parameter("metros", metros)
	m.set_shader_parameter("ruido", _ruido)
	m.set_shader_parameter("tinta", _tema.get("tinta", Color.WHITE))
	if nome_b != "" and kit(nome_b) != null:
		m.set_shader_parameter("textura_b", kit(nome_b))
		m.set_shader_parameter("usar_b", 1.0)
	return m


func _cor(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * Color(_tema.get("tinta", Color.WHITE))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- Camadas -----------------------------------------------------------------

func _chao(caixa: Rect2, k: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = caixa.size + Vector2(6000, 6000)
	mi.mesh = plano
	var m := _mat(k.get("chao_a", "grama_a"), 16.0, false, k.get("chao_b", "grama_b"))
	if _mascara != null:
		m.set_shader_parameter("usar_mascara", 1.0)
		m.set_shader_parameter("mascara", ImageTexture.create_from_image(_mascara))
		m.set_shader_parameter("mascara_origem", _campo_origem - Vector2.ONE * _campo_m * 0.5)
		m.set_shader_parameter("mascara_tam", Vector2(_campo_tam) * _campo_m)
		m.set_shader_parameter("textura_mata", kit(k.get("chao_mata", k.get("chao_b", "grama_b"))))
		m.set_shader_parameter("textura_agua", kit("agua"))
	mi.material_override = m
	var c := caixa.get_center()
	mi.position = Vector3(c.x, -0.06, -c.y)
	_cena.add_child(mi)


## Faixa entre dois deslocamentos laterais ao longo de [s0, s1], fechada se
## for a volta inteira. alfa_externo: o lado b apaga (borda irregular).
func _faixa(a: float, b: float, s0: float, s1: float, y: float, mat: Material, pontas := 0.0,
		alfa_externo := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passo := 3.0
	var n := maxi(int(ceil((s1 - s0) / passo)), 1)
	var antes := []
	for i in n + 1:
		var s := lerpf(s0, s1, float(i) / n)
		var ponta := 1.0
		if pontas > 0.0:
			ponta = clampf(minf(s - s0, s1 - s) / pontas, 0.0, 1.0)
		var pa := _ponto(s, a)
		var pb := _ponto(s, b)
		# UV de faixa (zebra): x atravessa a faixa, y corre ao longo (2 m por volta da textura).
		var ua := Vector2(0.0, (s - s0) / 2.0)
		var ub := Vector2(1.0, (s - s0) / 2.0)
		var atual := [[_v3(pa, y), ponta, ua], [_v3(pb, y), ponta * (0.0 if alfa_externo else 1.0), ub]]
		if not antes.is_empty():
			for v in [antes[0], antes[1], atual[0], antes[1], atual[1], atual[0]]:
				st.set_color(Color(1, 1, 1, v[1]))
				st.set_uv(v[2])
				st.add_vertex(v[0])
		antes = atual
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_cena.add_child(mi)
	return mi


func _faixa_volta(a: float, b: float, y: float, mat: Material) -> void:
	_faixa(a, b, 0.0, _pista.comprimento, y, mat)


## Areia por fora das curvas lentas, brita nas médias; borda externa irregular.
func _bordas_curvas(k: Dictionary) -> void:
	var areia := _mat(k.get("areia", "areia"), 16.0, true)
	areia.set_shader_parameter("borda_irregular", 0.6 * _borda_irregular)
	var brita := _mat("brita", 12.0, true)
	brita.set_shader_parameter("borda_irregular", 0.5 * _borda_irregular)
	for i in _pista.trechos.size():
		var t: Dictionary = _pista.trechos[i]
		var raio := float(t.get("raio_m", 0.0))
		if raio <= 0.0 or raio > RAIO_BRITA_M:
			continue
		var fora := -1.0 if t.get("sentido", "esquerda") == "esquerda" else 1.0
		var s0: float = _pista.inicios[i] - 15.0
		var s1: float = _pista.inicios[i] + float(t["comprimento_m"]) + 35.0
		var largo := AREIA_M if raio <= RAIO_AREIA_M else BRITA_M
		var a := (_largura * 0.5 + ESCAPE_M) * fora
		var b := (_largura * 0.5 + ESCAPE_M + largo) * fora
		_faixa(a, b, s0, s1, -0.025, areia if raio <= RAIO_AREIA_M else brita, 18.0, true)


func _zebras() -> void:
	var mat := _mat("zebra", 2.0)
	mat.set_shader_parameter("modo_uv", 1)
	for i in _pista.trechos.size():
		var t: Dictionary = _pista.trechos[i]
		if float(t.get("raio_m", 0.0)) <= 0.0:
			continue
		var s0: float = _pista.inicios[i] - 4.0
		var s1: float = _pista.inicios[i] + float(t["comprimento_m"]) + 4.0
		for lado in [-1.0, 1.0]:
			var a: float = lado * _largura * 0.5
			var b: float = lado * (_largura * 0.5 + ZEBRA_M)
			_faixa(minf(a, b), maxf(a, b), s0, s1, -0.01, mat)


## Boxes, arquibancada, torre e pórtico na reta da largada (por fora); paddock
## com caminhões e tendas do lado de dentro.
func _reta_de_largada(k: Dictionary) -> void:
	var i0 := _pista.indice_em(0.5)
	var reta: Dictionary = _pista.trechos[i0]
	var comp := float(reta["comprimento_m"]) if float(reta.get("raio_m", 0.0)) <= 0.0 else 120.0
	var s_ini: float = _pista.inicios[i0]
	var s_meio := s_ini + comp * 0.5
	# Lado de dentro: para onde fica o centro do traçado.
	var centro := _caixa().get_center()
	var normal := Vector2.from_angle(_pista.rumo_em(s_meio) + PI / 2.0)
	var dentro := 1.0 if (centro - _pista.posicao_em(s_meio)).dot(normal) > 0.0 else -1.0
	var fora := -dentro
	var b0 := _largura * 0.5 + ESCAPE_M
	var a := s_ini + comp * 0.12
	var b := s_ini + comp * 0.88
	# Até onde cada lado está livre de outro trecho da pista (grampo, curva que
	# volta): nada da reta de largada invade o resto do traçado.
	var livre_fora := _livre(a, b, fora, b0 + 60.0)
	var livre_dentro := _livre(a, b, dentro, b0 + 70.0)
	# Pit lane e pátio dos boxes.
	var conc := _mat("concreto", 16.0)
	var pit := minf(b0 + 26.0, livre_fora)
	_faixa(minf(fora * (b0 + 1.0), fora * pit), maxf(fora * (b0 + 1.0), fora * pit), a, b, -0.02, conc)
	_reservar(a - 10.0, b + 10.0, fora * b0, fora * maxf(livre_fora, b0 + 1.0))
	# Prédio dos boxes: módulos de 10 m encostados ao longo da reta. O eixo x do
	# sprite segue a pista e a borda de baixo (portas) fica virada para ela: com
	# o giro = rumo, a borda de baixo aponta para a direita do sentido da pista.
	var vira := 0.0 if fora > 0.0 else PI
	var s := a + 5.0
	while s < b - 5.0 and livre_fora >= b0 + 22.0:
		_objeto("box_modulo", _ponto(s, fora * (b0 + 18.0)), _pista.rumo_em(s) + vira, 5.0)
		_luz(_ponto(s, fora * (b0 + 12.0)), 7.0, LUZ_BOX)
		s += 10.0
	if livre_fora >= b0 + 22.0:
		_objeto("torre", _ponto(s + 1.5, fora * (b0 + 18.0)), _pista.rumo_em(s) + vira, 14.0)
	# Arquibancada atrás dos boxes, em módulos de 12 m encostados, no terço do meio.
	s = a + (b - a) * 0.3
	while s < a + (b - a) * 0.7 and livre_fora >= b0 + 39.0:
		_objeto("arquibancada_modulo", _ponto(s, fora * (b0 + 34.0)), _pista.rumo_em(s) + vira, 7.0)
		s += 12.0
	# Paddock dentro: pátio de concreto com caminhões e tendas em fileiras.
	var p0 := dentro * (b0 + 14.0)
	var p1 := dentro * livre_dentro
	if livre_dentro >= b0 + 34.0:
		_faixa(minf(p0, p1), maxf(p0, p1), a + comp * 0.08, b - comp * 0.08, -0.02, conc)
		_reservar(a, b, p0, p1)
	# Duas fileiras com espaço entre os veículos; tendas em grupos no meio.
	var fileira := 0
	for lat in [b0 + 28.0, b0 + 52.0]:
		if lat + 6.0 > livre_dentro:
			continue
		s = a + comp * 0.12 + fileira * 9.0
		while s < b - comp * 0.12:
			var nome := "tenda_%d" % (1 + _rng.randi() % 2) if _rng.randf() < 0.3 else "caminhao_%d" % (1 + _rng.randi() % 3)
			_objeto(nome, _ponto(s, dentro * lat), _pista.rumo_em(s) + PI / 2.0, 3.0)
			s += _rng.randf_range(16.0, 26.0)
		fileira += 1
	# Postes de iluminação: na beira do pátio dos boxes e no meio do paddock.
	if k.get("postes", true):
		s = a + 10.0
		while s < b - 10.0:
			_objeto("poste", _ponto(s, fora * (b0 + 1.0)), 0.0, 0.0, 0.4)
			_luz(_ponto(s, fora * (b0 + 1.0)), 16.0, LUZ_POSTE)
			if livre_dentro >= b0 + 46.0:
				_objeto("poste", _ponto(s + 20.0, dentro * (b0 + 40.0)), 0.0, 0.0, 0.4)
				_luz(_ponto(s + 20.0, dentro * (b0 + 40.0)), 22.0, LUZ_POSTE)
			s += POSTE_A_CADA_M
	# Pórtico sobre a largada.
	var portico := kit("portico")
	if portico != null:
		_objeto("portico", _pista.posicao_em(Corrida3D.PORTICO_M), _pista.rumo_em(Corrida3D.PORTICO_M),
				7.0, 0.6, true)


## Maior afastamento lateral (m), de b0 até ate, em que o lado continua longe de
## qualquer outro trecho do traçado, com folga para escape e caixa de areia.
func _livre(s0: float, s1: float, lado: float, ate: float) -> float:
	var folga := _largura * 0.5 + ESCAPE_M + AREIA_M
	var lat := _largura * 0.5 + ESCAPE_M
	while lat < ate:
		var s := s0
		while s <= s1:
			# O mais perto do ponto tem de ser a própria reta (a lat + folga).
			if _distancia(_ponto(s, lado * (lat + 2.0 + folga))) < lat + 2.0 + folga - 1.0:
				return lat
			s += 8.0
		lat += 2.0
	return ate


func _reservar(s0: float, s1: float, l0: float, l1: float) -> void:
	var poli := PackedVector2Array()
	var s := s0
	while s <= s1:
		poli.append(_ponto(s, l0))
		s += 10.0
	s = s1
	while s >= s0:
		poli.append(_ponto(s, l1))
		s -= 10.0
	_reservas.append(poli)


func _reservado(p: Vector2) -> bool:
	for poli in _reservas:
		if Geometry2D.is_point_in_polygon(p, poli):
			return true
	return false


# --- Objetos (sprites vistos de cima) ----------------------------------------

## Um objeto do kit no chão, girado, com sombra na direção da luz do tema.
## altura_m: o quanto a sombra se afasta (prédio alto, sombra longa).
## suspenso: objeto no alto (pórtico): a sombra é a silhueta deslocada, solta
## no chão, em vez de arrastada desde a base.
func _objeto(nome: String, p: Vector2, rumo: float, altura_m: float, y := 0.25, suspenso := false) -> void:
	var t := kit(nome)
	if t == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(t.get_width(), t.get_height()) / PX_M
	_desenho_objeto(nome, t, p, rumo, y)
	if altura_m > 0.0:
		var sombra := MeshInstance3D.new()
		var d: Vector2 = _tema.get("sombra_dir", Vector2(1.0, -0.6)) * altura_m
		sombra.mesh = _quad_sombra(t, d.length())
		sombra.material_override = _mat_sombra(t, d, q.size)
		if suspenso:
			sombra.material_override.set_shader_parameter("inicio", 1.0)
		sombra.position = _v3(p, 0.05)
		sombra.rotation.y = rumo
		_cena.add_child(sombra)


## O objeto em si (aqui, o sprite do kit deitado no chão); MontadorChapado
## troca por volumes de cor chapada.
func _desenho_objeto(nome: String, t: Texture2D, p: Vector2, rumo: float, y: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(t.get_width(), t.get_height()) / PX_M
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	mi.material_override = _mat_sprite(t, false)
	mi.position = _v3(p, y)
	mi.rotation.y = rumo
	_cena.add_child(mi)


## Quadro da sombra: o do sprite com folga do arrasto para todos os lados.
func _quad_sombra(t: Texture2D, arrasto_m: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(t.get_width(), t.get_height()) / PX_M + Vector2.ONE * arrasto_m * 2.0
	q.orientation = PlaneMesh.FACE_Y
	return q


static var _shader_sombra: Shader


## Sombra presa ao objeto: a silhueta arrastada d metros (shaders/sombra.gdshader).
func _mat_sombra(t: Texture2D, d: Vector2, tamanho_m: Vector2) -> ShaderMaterial:
	if _shader_sombra == null:
		_shader_sombra = preload("res://visual/shaders/sombra.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader_sombra
	m.set_shader_parameter("textura", t)
	m.set_shader_parameter("arrasto", Vector2(d.x, -d.y))
	m.set_shader_parameter("folga", (tamanho_m + Vector2.ONE * d.length() * 2.0) / tamanho_m)
	m.set_shader_parameter("alfa", float(_tema.get("sombra_alfa", 0.45)))
	return m


var _mats_sprite := {}


func _mat_sprite(t: Texture2D, sombra: bool) -> StandardMaterial3D:
	var chave := "%s|%s" % [t.resource_path, sombra]
	if _mats_sprite.has(chave):
		return _mats_sprite[chave]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = t
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if sombra:
		m.albedo_color = Color(0, 0, 0, float(_tema.get("sombra_alfa", 0.45)))
	else:
		m.albedo_color = Color(_tema.get("tinta", Color.WHITE))
		m.vertex_color_use_as_albedo = true  # cor por instância da mata (fundo escuro)
		m.render_priority = 1
	_mats_sprite[chave] = m
	return m


## Pátio de contêineres: um bloco de 5 a 8 encostados lado a lado, do mesmo
## comprimento, eixo longo na direção da reta de largada.
func _bloco_conteineres(centro: Vector2, rumo0: float, nomes: Array, por_nome: Dictionary, cores: Dictionary) -> void:
	var curtos := nomes.filter(func(n): return kit(n) != null and kit(n).get_height() < 300)
	var longos := nomes.filter(func(n): return kit(n) != null and kit(n).get_height() >= 300)
	var grupo: Array = curtos if not curtos.is_empty() and (longos.is_empty() or _rng.randf() < 0.3) else longos
	if grupo.is_empty():
		return
	var n := _rng.randi_range(5, 8)
	var lado := Vector2.from_angle(rumo0 + PI / 2.0)
	for i in n:
		var p := centro + lado * (i - (n - 1) * 0.5) * 2.6
		if _distancia(p) < MATA_MIN_M or _reservado(p):
			continue
		var nome: String = grupo[_rng.randi() % grupo.size()]
		var giro := rumo0 + PI / 2.0 + (PI if _rng.randf() < 0.5 else 0.0)
		por_nome.get_or_add(nome, []).append(Transform3D(Basis(Vector3.UP, giro), _v3(p, 0.3)))
		var claro := _claridade(_dist_campo(p))
		cores.get_or_add(nome, []).append(Color(claro, claro, claro))


## Mata: grade com sorteio, mais densa longe da pista, com clareiras (ruído).
## Um MultiMesh por variante, mais um para as sombras.
func _mata(caixa: Rect2, k: Dictionary) -> void:
	var nomes: Array = k.get("arvores", [])
	if nomes.is_empty():
		return
	var densidade: float = k.get("densidade", 1.0)
	var aberto: float = k.get("aberto_m", MATA_MIN_M)
	var por_nome := {}
	var cores := {}  # nome -> [Color]: copas mais escuras no fundo da mata
	# Alinhado (pátio de contêineres): fileiras na direção da reta de largada,
	# girados só de 0° ou 180°, sem sorteio de posição dentro da célula.
	var alinhado: bool = k.get("alinhado", false)
	var rumo0 := _pista.rumo_em(0.0)
	var passo := PASSO_CONTEINER_M if alinhado else PASSO_ARVORE_M
	# Raras: sorteadas com chance baixa no lugar de uma árvore (rochas na mata).
	var raras: Array = k.get("raras", [])
	var chance_rara: float = k.get("chance_rara", 0.0)
	var y := caixa.position.y
	while y < caixa.end.y:
		var x := caixa.position.x
		while x < caixa.end.x:
			var p := Vector2(x, y) + Vector2(_rng.randf_range(-0.45, 0.45), _rng.randf_range(-0.45, 0.45)) * PASSO_ARVORE_M
			if alinhado:
				p = Vector2(x, y).rotated(rumo0)
			x += passo
			var d := _dist_campo(p)
			if d < MATA_MIN_M or _reservado(p) or _agua(p, d) > 0.0:
				continue
			var chance: float
			if alinhado:
				# Pátios: zonas cheias de blocos, separadas por áreas vazias.
				chance = 1.0 if _clareira.get_noise_2d(p.x * 0.6, p.y * 0.6) > 0.05 and d > MATA_MIN_M + 10.0 else 0.0
			else:
				# Mata fechada depois da faixa aberta; nela, só árvores isoladas.
				chance = maxf(_floresta(p, d), ARVORE_ISOLADA * densidade if d < aberto else 0.0)
			if _rng.randf() > chance:
				continue
			if alinhado:
				_bloco_conteineres(p, rumo0, nomes, por_nome, cores)
				continue
			var lista_nomes: Array = raras if not raras.is_empty() and _rng.randf() < chance_rara else nomes
			var nome: String = lista_nomes[_rng.randi() % lista_nomes.size()]
			if kit(nome) == null:
				continue
			var escala := _rng.randf_range(0.85, 1.25)
			var fundo := smoothstep(aberto + 30.0, aberto + 180.0, d)
			var claro := _claridade(d)
			cores.get_or_add(nome, []).append(Color.WHITE.darkened(fundo * FUNDO_ESCURO + _rng.randf() * 0.08) * Color(claro, claro, claro))
			por_nome.get_or_add(nome, []).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * escala), _v3(p, 0.3)))
		y += passo
	for nome in por_nome:
		var t := kit(nome)
		var q := QuadMesh.new()
		q.size = Vector2(t.get_width(), t.get_height()) / PX_M
		q.orientation = PlaneMesh.FACE_Y
		var d_sombra: Vector2 = _tema.get("sombra_dir", Vector2(1.0, -0.6)) * float(k.get("altura_mata_m", ALTURA_MATA_M))
		_mata_desenho(nome, t, por_nome[nome], cores.get(nome, []))
		# Sombras de todas as árvores deste tipo num MultiMesh só.
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _quad_sombra(t, d_sombra.length())
		var lista: Array = por_nome[nome]
		mm.instance_count = lista.size()
		for i in lista.size():
			var tr: Transform3D = lista[i]
			tr.origin.y = 0.1
			mm.set_instance_transform(i, tr)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat_sombra(t, d_sombra, q.size)
		_cena.add_child(mmi)


## As árvores (ou objetos da mata) de um tipo: um MultiMesh do sprite, com cor
## por instância. MontadorChapado troca por volumes facetados.
func _mata_desenho(nome: String, t: Texture2D, lista: Array, cores: Array) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(t.get_width(), t.get_height()) / PX_M
	q.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cores.is_empty()
	mm.mesh = q
	mm.instance_count = lista.size()
	for i in lista.size():
		mm.set_instance_transform(i, lista[i])
		if mm.use_colors:
			mm.set_instance_color(i, cores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat_sprite(t, false)
	_cena.add_child(mmi)
