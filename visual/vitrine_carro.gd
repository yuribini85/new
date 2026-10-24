class_name VitrineCarro
extends SubViewportContainer
## Carro num estúdio (piso, luz de recorte, fundo escuro), como uma vitrine
## de garagem. Com a arte em sprite (decisão 31), o carro é o isométrico
## parado, a câmera fica no mesmo ângulo do desenho e os efeitos são de luz:
## feixe passando pela carroceria, reflexo no piso, sombra de contato e uma aproximação
## curta ao trocar de carro. Sem sprite, o carro em código gira como antes.

const VELOCIDADE := 0.35  # rad/s

var _carro: CarroBloco
var _mundo: Node3D
var _arrastando := false
var _ultimo_toque := 0.0
## Garagem: carro parado num ambiente de oficina, só balançando devagar.
var _garagem := false
var _angulo := -0.5
var _luz: DirectionalLight3D
var _piso: MeshInstance3D
var _anel: MeshInstance3D
## Oficina (pedido do usuário): o carro parado em três quartos, sem girar; ao
## trocar de carro, ele entra de lado numa derrapada curta e assenta.
var _estatico := false
var _deriva := 1.0  # 0 → 1 durante a derrapada
var _pos_base := Vector3.ZERO
const DERIVA_S := 1.1
const DERIVA_GIRO := 1.15  # rad a mais de traseira no começo
const DERIVA_DIST := 4.2  # m de lado no começo


func _init(altura := 300.0) -> void:
	stretch = true
	custom_minimum_size = Vector2(0, altura)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if Preferencias.efeitos_leves else Viewport.MSAA_4X
	add_child(vp)
	_mundo = Node3D.new()
	vp.add_child(_mundo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.075, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.58)
	CarroBloco.reflexo(env)  # o reflexo do verniz na pintura
	amb.environment = env
	_mundo.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(-0.85, 0.7, 0)
	luz.light_energy = 0.85
	_mundo.add_child(luz)
	_luz = luz
	var recorte := DirectionalLight3D.new()
	recorte.rotation = Vector3(-0.3, PI + 0.6, 0)
	recorte.light_energy = 0.45
	var frente := DirectionalLight3D.new()
	frente.rotation = Vector3(-0.2, 0.9, 0)
	frente.light_energy = 0.3
	_mundo.add_child(frente)
	recorte.light_color = Color(0.7, 0.8, 1.0)
	_mundo.add_child(recorte)
	var piso := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 3.8
	disco.bottom_radius = 3.9
	disco.height = 0.06
	disco.radial_segments = 48
	piso.mesh = disco
	piso.material_override = CarroBloco._material(Color(0.13, 0.135, 0.16))
	piso.position.y = -0.04
	_mundo.add_child(piso)
	_piso = piso
	var anel := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 3.75
	t.outer_radius = 3.9
	anel.mesh = t
	# Borda discreta: o carro é o destaque, não a plataforma.
	anel.material_override = CarroBloco._material(Color(0.24, 0.25, 0.29))
	_mundo.add_child(anel)
	_anel = anel
	var cam := Camera3D.new()
	cam.fov = 30
	_mundo.add_child(cam)
	cam.look_at_from_position(Vector3(6.2, 2.4, 6.8), Vector3(0, 0.5, 0))
	_camera = cam
	_carro = CarroBloco.new()
	_carro.rotation.y = -0.5
	_mundo.add_child(_carro)


func mostrar(categoria: String, cor: Color) -> void:
	_carro.configurar(categoria, cor)


## Blindagem montada no modelo mostrado (decisão 80; só modelos com proteção).
func blindar(id: String, nivel: int) -> void:
	if _carro is CarroBloco and _carro.visible:
		(_carro as CarroBloco).blindar(id, nivel)
		_pedir_quadro()


func mostrar_modelo(base: Dictionary, cor: Color, faixas: Dictionary = {}) -> void:
	if CarroBloco.tem_modelo(String(base.get("id", ""))):
		# Modelo 3D: na mesma câmera e no mesmo ângulo dos sprites da loja.
		_sprite_modo(true)
		_sprite.visible = false
		_reflexo.visible = false
		_carro.visible = true
		_carro.rotation.y = ROTACAO_MODELO
		_carro.configurar_modelo(base, cor, faixas)
		if _estatico:
			_angulo = ROTACAO_MODELO
			_trocou(String(base.get("id", "")))
		elif _id != String(base.get("id", "")) and not Preferencias.reduzir_animacoes and is_inside_tree():
			_aproximar = 0.0
		_id = String(base.get("id", ""))
		return
	_carro.rotation.y = -0.5
	if _estatico:
		_angulo = -0.5
		_trocou(String(base.get("id", "")))
	var tex := ArteCarro.textura(String(base.get("id", "")), "iso")
	if tex != null and Pintura.pintavel(String(base.get("id", ""))):
		tex = Pintura.textura(String(base.get("id", "")), "iso", cor)
	if tex == null:
		_sprite_modo(false)
		_carro.configurar_modelo(base, cor)
		return
	_sprite_modo(true)
	var novo: bool = _id != String(base.get("id", ""))
	_id = String(base.get("id", ""))
	var tam := Vector2(tex.get_width(), tex.get_height()) / ArteCarro.PX_POR_M
	for q in [_sprite, _reflexo]:
		(q.material_override as ShaderMaterial).set_shader_parameter("textura", tex)
	(_sprite.mesh as QuadMesh).size = tam
	# Reflexo: quadro com o dobro da altura, a metade de cima sobre o sprite;
	# o shader espelha cada coluna na linha do chão (apoio das rodas).
	(_reflexo.mesh as QuadMesh).size = Vector2(tam.x, tam.y * 2.0)
	_reflexo.position = _sprite.position - _camera.transform.basis.y * (tam.y * 0.5) \
			- _camera.transform.basis.z * 0.45
	var chao := _linha_chao(_id, tex)
	var m: ShaderMaterial = _reflexo.material_override
	m.set_shader_parameter("chao_a", chao[0])
	m.set_shader_parameter("chao_b", chao[1])
	if novo and not Preferencias.reduzir_animacoes and is_inside_tree():
		_aproximar = 0.0


## Linha do chão do sprite isométrico em UV: a reta pelo ponto mais baixo das
## duas rodas visíveis (arte/carros/rodas.json); sem rodas, a base do desenho.
static func _linha_chao(id: String, tex: Texture2D) -> Array:
	var tam := Vector2(tex.get_width(), tex.get_height())
	var rodas := ArteCarro.rodas(id)
	if rodas.size() >= 2:
		var p: Array = []
		for r in rodas.slice(0, 2):
			var c := Vector2(r["c"][0], r["c"][1])
			var b := Vector2(r["b"][0], r["b"][1])
			var a := Vector2(r["a"][0], r["a"][1])
			p.append(Vector2(c.x, c.y + sqrt(a.y * a.y + b.y * b.y)) / tam)
		if absf(p[0].x - p[1].x) > 0.05:
			return p if p[0].x < p[1].x else [p[1], p[0]]
	var y := float(tex.get_image().get_used_rect().end.y) / tam.y
	return [Vector2(0.0, y), Vector2(1.0, y)]


var _camera: Camera3D
var _sprite: MeshInstance3D
var _reflexo: MeshInstance3D
var _id := ""
## 0..1 da aproximação de entrada (1 = parada).
var _aproximar := 1.0
## Giro do modelo 3D na vitrine: frente para baixo e à esquerda, como nos sprites.
const ROTACAO_MODELO := -PI / 2.0 - 0.25
## Largura vista pela câmera no modo sprite (m): o carro ocupa ~2/3 dela.
const LARGURA_VISTA_M := 6.6


func _sprite_modo(ligado: bool) -> void:
	_carro.visible = not ligado
	if not ligado:
		if _sprite != null:
			_sprite.visible = false
			_reflexo.visible = false
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.look_at_from_position(Vector3(6.2, 2.4, 6.8), Vector3(0, 0.5, 0))
		return
	# A mesma direção da câmera da corrida e do sprite isométrico.
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = LARGURA_VISTA_M
	_camera.far = 200.0
	_camera.look_at_from_position(Vector3(70, 57.15, 70).normalized() * 40.0 + Vector3(0, 0.6, 0), Vector3(0, 0.6, 0))
	if _sprite == null:
		_sprite = _quadro(0.0)
		_reflexo = _quadro(0.28)
	_sprite.visible = true
	_reflexo.visible = true


## Quadro virado para a câmera com o shader do sprite (reflexo > 0: reflexo
## espelhado no piso e sombra de contato).
func _quadro(reflexo: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = preload("res://visual/shaders/brilho_carro.gdshader")
	m.set_shader_parameter("reflexo", reflexo)
	mi.material_override = m
	_mundo.add_child(mi)
	mi.transform.basis = _camera.transform.basis
	m.render_priority = 0 if reflexo > 0.0 else 1  # o reflexo por baixo do carro
	mi.position = Vector3(0, 0.6, 0) + _camera.transform.basis.z * (-0.05 if reflexo > 0.0 else 0.4)
	return mi


## Fundo pintado (arte da interface) no lugar do estúdio: a imagem fica atrás
## do carro (fundo do próprio viewport), sem piso nem anel; o carro em sprite
## mantém sombra de contato e reflexo leve.
func fundo_imagem(tex: Texture2D) -> void:
	if tex == null:
		return
	_piso.visible = false
	_anel.visible = false
	var vp: SubViewport = get_child(0)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(t)
	vp.move_child(t, 0)
	_pedir_quadro()
	var ambiente: Environment = (_mundo.get_child(0) as WorldEnvironment).environment
	ambiente.background_mode = Environment.BG_CANVAS


## Sem fundo: o viewport fica transparente e a tela por trás aparece (a
## Oficina pinta o cenário atrás de tudo); o sprite mantém sombra e reflexo.
func fundo_transparente() -> void:
	_piso.visible = false
	_anel.visible = false
	var vp: SubViewport = get_child(0)
	vp.transparent_bg = true
	var ambiente: Environment = (_mundo.get_child(0) as WorldEnvironment).environment
	ambiente.background_mode = Environment.BG_CLEAR_COLOR
	_pedir_quadro()


## Luz de fim de tarde (pedido do usuário; o clima das cenas e do fundo da
## Oficina): o sol quente entrando pela porta, de lado e de trás, com sombra; o
## ambiente baixo e morno; um preenchimento frio fraco do outro lado, para o
## carro não chapar; e um recorte âmbar contornando o teto.
func luz_fim_de_tarde() -> void:
	var ambiente: Environment = (_mundo.get_child(0) as WorldEnvironment).environment
	ambiente.ambient_light_color = Color(0.4, 0.38, 0.37)
	ambiente.ambient_light_energy = 1.0
	_luz.rotation = Vector3(-0.5, -0.9, 0)  # da porta (à esquerda, atrás)
	_luz.light_color = Color(1.0, 0.86, 0.7)
	_luz.light_energy = 1.05
	_luz.shadow_enabled = not Preferencias.efeitos_leves
	for n in _mundo.get_children():
		if n is DirectionalLight3D and n != _luz:
			var d := n as DirectionalLight3D
			if d.light_color.b > d.light_color.r:  # o recorte frio vira âmbar, por trás
				d.light_color = Color(1.0, 0.72, 0.45)
				d.light_energy = 0.45
			else:  # a frente vira o preenchimento frio e fraco
				d.light_color = Color(0.62, 0.68, 0.82)
				d.light_energy = 0.3
	_pedir_quadro()


## Troca o estúdio por uma oficina: piso de ladrilhos, paredes, armário,
## pneus empilhados, bancada, luminária e sombra de verdade.
func ambiente_garagem() -> void:
	if _garagem:
		return
	_garagem = true
	_piso.visible = false
	_anel.visible = false
	# Ambiente escuro e o carro como ponto de luz: foco de cima sobre ele.
	_luz.shadow_enabled = not Preferencias.efeitos_leves
	_luz.rotation = Vector3(-1.1, 0.5, 0)
	_luz.light_energy = 0.35
	var ambiente: Environment = (_mundo.get_child(0) as WorldEnvironment).environment
	ambiente.ambient_light_color = Color(0.3, 0.31, 0.35)
	ambiente.background_color = Color(0.05, 0.05, 0.06)
	var foco := SpotLight3D.new()
	foco.position = Vector3(0.6, 5.5, 1.2)
	foco.rotation = Vector3(-PI / 2.0 + 0.15, 0, 0)
	foco.spot_angle = 38.0
	foco.spot_range = 12.0
	foco.light_energy = 3.2
	foco.light_color = Color(1.0, 0.96, 0.9)
	foco.shadow_enabled = not Preferencias.efeitos_leves
	_mundo.add_child(foco)
	var claro := CarroBloco._material(Color(0.17, 0.175, 0.19))
	var escuro := CarroBloco._material(Color(0.14, 0.145, 0.16))
	for i in range(-6, 7):
		for k in range(-6, 7):
			var ladrilho := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(1.0, 0.04, 1.0)
			ladrilho.mesh = b
			ladrilho.material_override = claro if (i + k) % 2 == 0 else escuro
			ladrilho.position = Vector3(i, -0.02, k)
			_mundo.add_child(ladrilho)
	var parede := CarroBloco._material(Color(0.22, 0.23, 0.26))
	var faixa := CarroBloco._material(Color(0.5, 0.38, 0.1))
	for p in [[Vector3(13.0, 4.0, 0.2), Vector3(0, 2.0, -6.5)], [Vector3(0.2, 4.0, 13.0), Vector3(-6.5, 2.0, 0)]]:
		_bloco(p[0], p[1], parede)
		_bloco(Vector3(p[0].x, 0.25, p[0].z) + Vector3(0.02, 0, 0.02), p[1] + Vector3(0, -0.9, 0), faixa)
	# Armário de ferramentas vermelho com gavetas.
	var vermelho := CarroBloco._material(Color(0.75, 0.12, 0.1))
	_bloco(Vector3(1.6, 1.4, 0.7), Vector3(-3.2, 0.7, -6.0), vermelho)
	for g in 4:
		_bloco(Vector3(1.45, 0.04, 0.02), Vector3(-3.2, 0.3 + g * 0.3, -5.64), CarroBloco._material(Color(0.2, 0.2, 0.22)))
	# Bancada.
	var madeira := CarroBloco._material(Color(0.45, 0.32, 0.2))
	_bloco(Vector3(2.4, 0.1, 0.8), Vector3(1.6, 1.0, -6.0), madeira)
	for x in [0.5, 2.7]:
		_bloco(Vector3(0.1, 1.0, 0.7), Vector3(x, 0.5, -6.0), escuro)
	# Pneus empilhados no canto.
	var borracha := CarroBloco._material(Color(0.08, 0.08, 0.09))
	for n in 4:
		var pneu := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.36
		cil.bottom_radius = 0.36
		cil.height = 0.24
		cil.radial_segments = 16
		pneu.mesh = cil
		pneu.material_override = borracha
		pneu.position = Vector3(-5.6, 0.12 + n * 0.25, -5.4)
		_mundo.add_child(pneu)
	# Luminária com luz quente sobre o carro.
	var lampada := CarroBloco._material(Color(1.0, 0.95, 0.8))
	lampada.emission_enabled = true
	lampada.emission = Color(1.0, 0.92, 0.75)
	_bloco(Vector3(2.4, 0.08, 0.3), Vector3(0, 3.6, 0), lampada)
	var luz := OmniLight3D.new()
	luz.position = Vector3(0, 3.3, 0)
	luz.omni_range = 9.0
	luz.light_energy = 0.35
	luz.light_color = Color(1.0, 0.93, 0.8)
	_mundo.add_child(luz)


func _bloco(tam: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	_mundo.add_child(mi)


func _gui_input(ev: InputEvent) -> void:
	if _carro != null and not _carro.visible:
		return  # sprite: sem girar
	if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_angulo += ev.relative.x * 0.01
		_carro.rotation.y = _angulo
		_ultimo_toque = Time.get_ticks_msec() / 1000.0
		if _livre:
			# Cabine de pintura: o arrasto vertical sobe e desce a câmera.
			_elevacao = clampf(_elevacao - ev.relative.y * 0.3, ELEVACAO_MIN, ELEVACAO_MAX)
			_posicionar_camera()
		_pedir_quadro()
	elif _livre and (ev is InputEventMagnifyGesture or (ev is InputEventMouseButton and ev.pressed
			and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN])):
		var f: float = ev.factor if ev is InputEventMagnifyGesture else (1.1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 0.9)
		_zoom = clampf(_zoom * f, ZOOM_MIN, ZOOM_MAX)
		_posicionar_camera()
		_pedir_quadro()


## Cabine de pintura: o carro parado no giro e na altura de câmera pedidos
## (vistas 3/4, lateral, traseira, topo); o dedo gira, sobe e desce; pinça
## aproxima. Só para o modelo 3D.
const ELEVACAO_MIN := 8.0
const ELEVACAO_MAX := 88.0
const ZOOM_MIN := 0.75
const ZOOM_MAX := 1.35
## Giros do modelo para cada vista (a câmera fica a 45° do lado, como nos sprites).
const VISTAS := {"3/4": [ROTACAO_MODELO, 30.0], "lateral": [PI / 4.0, 12.0],
		"traseira": [ROTACAO_MODELO + PI, 26.0], "topo": [ROTACAO_MODELO, 88.0]}
var _livre := false
var _elevacao := 30.0
var _zoom := 1.0


func vista(nome: String) -> void:
	_livre = true
	var v: Array = VISTAS[nome]
	_angulo = v[0]
	_carro.rotation.y = _angulo
	_elevacao = v[1]
	_zoom = 1.0
	_ultimo_toque = INF  # parado: sem balançar nem girar sozinho
	_posicionar_camera()
	_pedir_quadro()


func _posicionar_camera() -> void:
	var el := deg_to_rad(_elevacao)
	var dir := Vector3(cos(el) * 0.7071, sin(el), cos(el) * 0.7071)
	_camera.size = LARGURA_VISTA_M / _zoom
	# De cima, a luminária do teto da oficina ficaria entre a câmera e o carro:
	# o plano de corte começa logo acima do teto do carro.
	_camera.near = 37.5 if _elevacao > 60.0 else 0.05
	_camera.look_at_from_position(dir * 40.0 + Vector3(0, 0.6, 0), Vector3(0, 0.6, 0),
			Vector3.FORWARD if _elevacao > 85.0 else Vector3.UP)


## Troca só a pintura do carro mostrado (sem recarregar o modelo).
func repintar(cor: Color, faixas: Dictionary) -> void:
	_carro.repintar(cor, faixas)
	_pedir_quadro()


## O quadro atual da vitrine (miniaturas da cabine).
func imagem() -> Image:
	var vp: SubViewport = get_child(0)
	return vp.get_texture().get_image()


func pedir_quadro() -> void:
	_pedir_quadro()


## Desenha o 3D só quando algo se mexe: parado (sprite, animação reduzida),
## um quadro basta e a vitrine não gasta GPU a cada quadro.
func _animando(sim: bool) -> void:
	var vp: SubViewport = get_child(0)
	if sim:
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	elif vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Um quadro novo (troca de carro, fundo, tamanho, giro com o dedo).
func _pedir_quadro() -> void:
	var vp: SubViewport = get_child(0)
	if vp.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_pedir_quadro()


## Liga o modo parado (Oficina).
func modo_estatico() -> void:
	_estatico = true
	_pos_base = _carro.position


## Carro novo no modo parado: a derrapada (o primeiro carro só aparece).
func _trocou(id: String) -> void:
	if _id_estatico != "" and _id_estatico != id and not Preferencias.reduzir_animacoes:
		_deriva = 0.0
	_id_estatico = id
	_pose_deriva()


## Pose do carro 3D no ponto atual da derrapada: a traseira vem aberta e fecha
## com um pequeno passe do ponto, a carroceria inclina e assenta.
func _pose_deriva() -> void:
	var e := 1.0 - pow(1.0 - _deriva, 2.0)  # freia devagar: desliza até assentar
	var volta := sin(_deriva * PI) * 0.18 * (1.0 - _deriva)
	_carro.rotation.y = _angulo + DERIVA_GIRO * (1.0 - e) - volta
	_carro.rotation.z = sin(_deriva * PI) * 0.05
	_carro.position = _pos_base + Vector3(-DERIVA_DIST * (1.0 - e), 0, 0)


var _id_estatico := ""


func _process(delta: float) -> void:
	if _estatico and (_sprite == null or not _sprite.visible):
		# Parado em três quartos; na troca, entra de lado derrapando.
		_animando(_deriva < 1.0)
		if _deriva < 1.0:
			# Passo limitado: o quadro lento de carregar o modelo não come o começo.
			_deriva = minf(_deriva + minf(delta, 1.0 / 30.0) / DERIVA_S, 1.0)
			_pose_deriva()
		return
	if _sprite != null and _sprite.visible:
		if _estatico:
			# Sprite (o desenho isométrico): a derrapada é o carro entrando de lado
			# e freando; a câmera desliza o quadro.
			_animando(_deriva < 1.0)
			if _deriva < 1.0:
				_deriva = minf(_deriva + minf(delta, 1.0 / 30.0) / DERIVA_S, 1.0)
			var ef := 1.0 - pow(1.0 - _deriva, 2.0)
			_camera.h_offset = DERIVA_DIST * 1.6 * (1.0 - ef) - sin(_deriva * PI) * 0.15 * (1.0 - _deriva)
			return
		# Aproximação curta ao trocar de carro (1,06 → 1,00).
		_animando(_aproximar < 1.0)
		if _aproximar < 1.0:
			_aproximar = minf(_aproximar + delta / 0.5, 1.0)
		_camera.size = LARGURA_VISTA_M * lerpf(1.06, 1.0, smoothstep(0.0, 1.0, _aproximar))
		return
	# Gira sozinho, exceto logo depois de o jogador girar com o dedo.
	var parado: bool = _livre or not is_visible_in_tree() or Preferencias.reduzir_animacoes \
			or Time.get_ticks_msec() / 1000.0 - _ultimo_toque < 3.0
	_animando(not parado)
	if parado:
		return
	if _garagem:
		# Na garagem o carro fica parado para ser observado: só balança devagar.
		_carro.rotation.y = _angulo + sin(Time.get_ticks_msec() / 1000.0 * 0.35) * 0.3
	else:
		_angulo += VELOCIDADE * delta
		_carro.rotation.y = _angulo
