class_name Piloto3D
extends Node3D
## Piloto que foge do carro em chamas na arena (pacote de dano aprovado pelo
## usuário; corpo, esqueleto, animações e ragdoll adaptados de
## pedestrian.gd do pacote). A simulação (Arena._piloto) decide onde ele está
## e quando é atropelado; aqui só se mostra: correndo, ele segue as amostras;
## atropelado, vira ragdoll com o impulso do carro (física só na tela); ao
## levantar, sai de onde o corpo caiu e volta ao ponto da simulação enquanto
## se levanta. Animações-fonte CC0 (arte/dano/LICENSE-ANIMATIONS.txt).

const MOVIMENTO := "res://arte/dano/pilot-motion.json"
const OSSO := preload("res://visual/osso_ragdoll.gd")
## Velocidade do ciclo "Jog_Fwd_Loop" sem acelerar (pacote: walk_speed).
const V_CICLO := 2.4
const ESTATURA := 0.88
## Camadas (pacote, adaptadas ao jogo): 1 chão, 2 objetos e piloto, 4 carros.
const CAMADA_CHAO := 1
const CAMADA_CARRO := 4

var estado := "correndo"
var skeleton: Skeleton3D
var animacao: AnimationPlayer
var _visual: Node3D
var _bones := {}
var _global := {}  # osso -> posição de repouso global
var _superficie: SurfaceTool
var _simulador: PhysicalBoneSimulator3D
var _ossos: Array[PhysicalBone3D] = []
var _corpo: PhysicalBone3D
var _de := Vector3.ZERO  # onde o corpo parou (levantando)
var _para := Vector3.ZERO  # onde a simulação o quer
var _levantar := 0.0
var _levantar_s := 1.68


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	_visual.add_child(skeleton)
	_osso("root", "", Vector3.ZERO)
	_osso("pelvis", "root", Vector3(0, .94, 0))
	_osso("spine", "pelvis", Vector3(0, 1.10, 0))
	_osso("chest", "spine", Vector3(0, 1.38, 0))
	_osso("neck", "chest", Vector3(0, 1.55, 0))
	_osso("head", "neck", Vector3(0, 1.65, 0))
	for lado in ["L", "R"]:
		var s := -1.0 if lado == "L" else 1.0
		_osso("shoulder_" + lado, "chest", Vector3(s * .17, 1.42, 0))
		_osso("arm_" + lado, "shoulder_" + lado, Vector3(s * .225, 1.41, 0))
		_osso("forearm_" + lado, "arm_" + lado, Vector3(s * .235, 1.13, 0))
		_osso("hand_" + lado, "forearm_" + lado, Vector3(s * .235, .89, 0))
		_osso("thigh_" + lado, "pelvis", Vector3(s * .085, .94, 0))
		_osso("shin_" + lado, "thigh_" + lado, Vector3(s * .085, .53, 0))
		_osso("foot_" + lado, "shin_" + lado, Vector3(s * .085, .11, 0))
	skeleton.reset_bone_poses()
	_malha()
	_ragdoll()
	_animacoes()


## Correndo: no ponto da simulação, de frente para o rumo (2D, rad).
func correr(onde: Vector3, rumo: float, v: float) -> void:
	if estado == "levantando":
		_para = onde
		return
	if estado != "correndo":
		return
	global_position = onde
	_visual.rotation.y = rumo + PI / 2.0  # a malha olha para +Z
	animacao.speed_scale = v / V_CICLO


## Segue em frente (depois do muro, saindo da arena).
func avancar(d: float) -> void:
	var r := _visual.rotation.y
	global_position += Vector3(sin(r), 0, cos(r)) * d


## Atropelado: o corpo é lançado como no pacote (horizontal × 0,42, subida ×
## 0,58 da velocidade do carro, cambalhota acima de 4 m/s).
func atropelar(v_carro: Vector3) -> void:
	if estado != "correndo":
		return
	estado = "caido"
	animacao.pause()
	for b in _ossos:
		b.collision_layer = 2
		b.collision_mask = CAMADA_CHAO | CAMADA_CARRO
	_simulador.active = true
	_simulador.physical_bones_start_simulation()
	var h := Vector3(v_carro.x, 0, v_carro.z)
	var v := h.length()
	var lanca := h * .42
	lanca.y = clampf(v * .58, 1.0, 7.5)
	var cambalhota := h.normalized().cross(Vector3.UP) * 2.4 if v > 4 else Vector3.ZERO
	for b in _ossos:
		b.linear_velocity = lanca
		b.angular_velocity = cambalhota
		b.linear_damp = .12


## Levanta de onde o corpo caiu e anda até o ponto da simulação no tempo do
## LayToIdle (a simulação espera o mesmo tempo).
func levantar(onde: Vector3, duracao: float) -> void:
	if estado != "caido":
		return
	# Pose de onde o corpo caiu: os ossos com corpo físico pela posição dele;
	# os outros (raiz, ombros, pescoço) presos ao pai como no repouso.
	var fisicos := {}
	for b in _ossos:
		fisicos[skeleton.find_bone(b.bone_name)] = b.global_transform * b.body_offset.affine_inverse()
	var globais: Array[Transform3D] = []
	for i in skeleton.get_bone_count():
		var pai := skeleton.get_bone_parent(i)
		if fisicos.has(i):
			globais.append(fisicos[i])
		elif pai >= 0:
			globais.append(globais[pai] * skeleton.get_bone_rest(i))
		else:
			globais.append(skeleton.global_transform * skeleton.get_bone_global_pose(i))
	_de = Vector3(_corpo.global_position.x, onde.y, _corpo.global_position.z)
	_para = onde
	_simulador.physical_bones_stop_simulation()
	_simulador.active = false
	for b in _ossos:
		b.collision_layer = 0
		b.collision_mask = 0
	global_position = _de
	animacao.stop(true)
	for i in skeleton.get_bone_count():
		var pai := skeleton.get_bone_parent(i)
		var local: Transform3D = skeleton.global_transform.affine_inverse() * globais[i] if pai < 0 \
				else globais[pai].affine_inverse() * globais[i]
		skeleton.set_bone_pose_position(i, local.origin)
		skeleton.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
	estado = "levantando"
	_levantar = 0.0
	_levantar_s = maxf(duracao, 0.1)
	animacao.speed_scale = 1.0
	animacao.play("LayToIdle", .35)


func _process(delta: float) -> void:
	if estado != "levantando":
		return
	_levantar += delta
	var u := clampf(_levantar / _levantar_s, 0.0, 1.0)
	global_position = _de.lerp(_para, u * u * (3.0 - 2.0 * u))
	if u >= 1.0:
		estado = "correndo"
		animacao.play("Jog_Fwd_Loop", .2)


# --- Corpo (do pacote) -------------------------------------------------------------

func _osso(id: String, pai: String, em: Vector3) -> void:
	em *= ESTATURA
	var i := skeleton.get_bone_count()
	skeleton.add_bone(id)
	_bones[id] = i
	var ip: int = _bones[pai] if pai != "" else -1
	skeleton.set_bone_parent(i, ip)
	# Posição global guardada aqui: no Godot 4.4 get_bone_global_rest() não
	# se atualiza logo depois de set_bone_rest() (os ossos esticavam).
	_global[id] = em
	var local := em
	if ip >= 0:
		local -= _global[pai]
	skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))


func _secao(y: float, w: float, d: float, centro: Vector3) -> Array:
	var b := minf(w, d) * .20
	var anel := []
	for xz in [Vector2(-w / 2 + b, -d / 2), Vector2(w / 2 - b, -d / 2), Vector2(w / 2, -d / 2 + b), Vector2(w / 2, d / 2 - b),
			Vector2(w / 2 - b, d / 2), Vector2(-w / 2 + b, d / 2), Vector2(-w / 2, d / 2 - b), Vector2(-w / 2, -d / 2 + b)]:
		anel.append(centro + Vector3(xz.x, y, xz.y))
	return anel


func _triangulo(a: Vector3, b: Vector3, c: Vector3, i: int, cor: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.length_squared() < .5:
		return
	for v in [a, b, c]:
		_superficie.set_normal(n)
		_superficie.set_color(cor)
		var nome := skeleton.get_bone_name(i)
		var outro := i
		var peso := 0.0
		if nome == "spine" and v.y > 1.18:
			outro = _bones["chest"]
			peso = clampf((v.y - 1.18) / .12, 0, .45)
		elif nome == "chest" and v.y < 1.29:
			outro = _bones["spine"]
			peso = clampf((1.29 - v.y) / .12, 0, .45)
		elif nome == "pelvis" and v.y > .98:
			outro = _bones["spine"]
			peso = clampf((v.y - .98) / .12, 0, .35)
		elif nome == "spine" and v.y < 1.08:
			outro = _bones["pelvis"]
			peso = clampf((1.08 - v.y) / .12, 0, .35)
		elif nome.begins_with("arm") and v.y > 1.37:
			outro = _bones["chest"]
			peso = clampf((v.y - 1.37) / .15, 0, .30)
		elif nome.begins_with("forearm") and v.y > 1.08:
			outro = _bones[nome.replace("forearm", "arm")]
			peso = clampf((v.y - 1.08) / .10, 0, .45)
		elif nome.begins_with("arm") and v.y < 1.18:
			outro = _bones[nome.replace("arm", "forearm")]
			peso = clampf((1.18 - v.y) / .10, 0, .45)
		elif nome.begins_with("shin") and v.y > .49:
			outro = _bones[nome.replace("shin", "thigh")]
			peso = clampf((v.y - .49) / .10, 0, .45)
		elif nome.begins_with("thigh") and v.y < .57:
			outro = _bones[nome.replace("thigh", "shin")]
			peso = clampf((.57 - v.y) / .10, 0, .45)
		_superficie.set_bones(PackedInt32Array([i, outro, 0, 0]))
		_superficie.set_weights(PackedFloat32Array([1 - peso, peso, 0, 0]))
		_superficie.add_vertex(v * ESTATURA)


func _volume(id: String, y0: float, y1: float, w0: float, w1: float, d0: float, d1: float, cor: Color,
		centro := Vector3.ZERO) -> void:
	var baixo := _secao(y0, w0, d0, centro)
	var alto := _secao(y1, w1, d1, centro)
	var i: int = _bones[id]
	for j in 8:
		var k := (j + 1) % 8
		_triangulo(baixo[j], alto[k], baixo[k], i, cor)
		_triangulo(baixo[j], alto[j], alto[k], i, cor)
	for j in range(1, 7):
		_triangulo(baixo[0], baixo[j], baixo[j + 1], i, cor)
		_triangulo(alto[0], alto[j + 1], alto[j], i, cor)


func _capacete() -> void:
	var aneis := []
	for linha in 7:
		var lat := lerpf(-PI / 2, PI / 2, float(linha) / 6)
		var anel := []
		for j in 16:
			var ang := TAU * float(j) / 16
			anel.append(Vector3(sin(ang) * cos(lat) * .12, 1.70 + sin(lat) * .14, cos(ang) * cos(lat) * .14))
		aneis.append(anel)
	for linha in 6:
		for j in 16:
			var k := (j + 1) % 16
			var ang := TAU * (float(j) + .5) / 16
			var cor := Color("d7d2bf")
			if (linha == 3 or linha == 4) and cos(ang) > .35:
				cor = Color("202d35")
			elif linha == 5 and (j == 0 or j == 15):
				cor = Color("b95539")
			elif linha == 0 or linha == 1:
				cor = Color("ada793")
			_triangulo(aneis[linha][j], aneis[linha][k], aneis[linha + 1][k], _bones["head"], cor)
			_triangulo(aneis[linha][j], aneis[linha + 1][k], aneis[linha + 1][j], _bones["head"], cor)


func _malha() -> void:
	_superficie = SurfaceTool.new()
	_superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var macacao := Color("a34f37")
	var escuro := Color("393e3e")
	var creme := Color("d4c9ad")
	_volume("pelvis", .87, 1.04, .28, .30, .19, .20, macacao)
	_volume("spine", 1.01, 1.24, .31, .30, .20, .19, macacao)
	_volume("chest", 1.23, 1.49, .30, .39, .19, .22, macacao)
	_volume("neck", 1.48, 1.57, .11, .10, .11, .10, escuro)
	_capacete()
	_volume("head", 1.575, 1.635, .15, .17, .055, .075, creme, Vector3(0, 0, .112))
	_volume("chest", 1.26, 1.48, .014, .014, .008, .008, escuro, Vector3(0, 0, .113))
	_volume("spine", 1.04, 1.24, .014, .014, .008, .008, escuro, Vector3(0, 0, .103))
	_volume("pelvis", 1.00, 1.035, .305, .305, .205, .205, escuro)
	for lado in ["L", "R"]:
		var x := -.235 if lado == "L" else .235
		_volume("arm_" + lado, 1.12, 1.43, .09, .14, .10, .15, macacao, Vector3(x, 0, 0))
		_volume("arm_" + lado, 1.35, 1.43, .133, .143, .143, .153, creme, Vector3(x, 0, 0))
		_volume("forearm_" + lado, .89, 1.14, .078, .091, .085, .10, macacao, Vector3(x, 0, 0))
		_volume("forearm_" + lado, .90, .95, .080, .083, .088, .092, creme, Vector3(x, 0, 0))
		_volume("hand_" + lado, .80, .93, .074, .08, .085, .085, escuro, Vector3(x, 0, .012))
		x = -.085 if lado == "L" else .085
		_volume("thigh_" + lado, .51, .96, .11, .13, .12, .15, macacao, Vector3(x, 0, 0))
		_volume("shin_" + lado, .10, .54, .082, .11, .094, .12, macacao, Vector3(x, 0, 0))
		_volume("shin_" + lado, .43, .56, .113, .113, .123, .123, escuro, Vector3(x, 0, 0))
		_volume("shin_" + lado, .10, .27, .087, .094, .104, .11, escuro, Vector3(x, 0, 0))
		_volume("foot_" + lado, .035, .13, .11, .10, .23, .17, escuro, Vector3(x, 0, .055))
		_volume("foot_" + lado, .022, .040, .115, .115, .235, .235, Color("252a29"), Vector3(x, 0, .055))
	var mi := MeshInstance3D.new()
	mi.mesh = _superficie.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = skeleton.create_skin_from_rest_transforms()


func _osso_fisico(id: String, desloc: Vector3, massa: float, dobradica := false) -> void:
	var pb := PhysicalBone3D.new()
	pb.set_script(OSSO)
	pb.name = "Physical_" + id
	_simulador.add_child(pb)
	pb.bone_name = id
	pb.mass = massa
	pb.friction = .65
	pb.linear_damp = .65
	pb.angular_damp = 1.2
	pb.collision_layer = 0
	pb.collision_mask = 0
	pb.body_offset = Transform3D(Basis.IDENTITY, desloc * ESTATURA)
	pb.joint_offset = Transform3D(Basis.IDENTITY, -desloc * ESTATURA)
	if id == "pelvis":
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
	elif dobradica:
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		pb.joint_rotation = Vector3(0, PI / 2, 0)
		pb.set("joint_constraints/angular_limit_enabled", true)
		pb.set("joint_constraints/angular_limit_lower", 0.0 if id.begins_with("shin") else -1.8)
		pb.set("joint_constraints/angular_limit_upper", 2.25 if id.begins_with("shin") else .12)
	else:
		pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		pb.joint_rotation = Vector3(0, 0, PI / 2)
		pb.set("joint_constraints/swing_span", deg_to_rad(65 if id.begins_with("arm") or id.begins_with("thigh") else 25))
		pb.set("joint_constraints/twist_span", deg_to_rad(30))
	_ossos.append(pb)


func _forma_osso(id: String, tam: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tam * ESTATURA
	cs.shape = caixa
	_simulador.get_node("Physical_" + id).add_child(cs)


func _ragdoll() -> void:
	_simulador = PhysicalBoneSimulator3D.new()
	skeleton.add_child(_simulador)
	var partes := [["pelvis", Vector3.ZERO, Vector3(.25, .18, .16), 10.0, false],
		["spine", Vector3(0, .09, 0), Vector3(.23, .20, .16), 10.0, false],
		["chest", Vector3(0, -.015, 0), Vector3(.28, .23, .17), 16.0, false],
		["head", Vector3(0, .08, 0), Vector3(.12, .20, .12), 5.0, false]]
	for lado in ["L", "R"]:
		partes.append(["arm_" + lado, Vector3(0, -.14, 0), Vector3(.075, .26, .075), 3.0, false])
		partes.append(["forearm_" + lado, Vector3(0, -.12, 0), Vector3(.065, .21, .065), 1.8, true])
		partes.append(["hand_" + lado, Vector3(0, -.045, 0), Vector3(.06, .10, .06), .6, false])
		partes.append(["thigh_" + lado, Vector3(0, -.20, 0), Vector3(.085, .38, .09), 5.0, false])
		partes.append(["shin_" + lado, Vector3(0, -.21, 0), Vector3(.07, .39, .075), 3.0, true])
		partes.append(["foot_" + lado, Vector3(0, -.025, .05), Vector3(.10, .085, .20), .7, false])
	for p in partes:
		_osso_fisico(p[0], p[1], p[3], p[4])
		_forma_osso(p[0], p[2])
	_corpo = _ossos[0]
	_simulador.physical_bones_stop_simulation()
	# No Godot 4.4 o simulador parado ainda escreve as poses dos ossos (o
	# corpo esticava): desligado fora da queda.
	_simulador.active = false


func _animacoes() -> void:
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOVIMENTO))
	animacao = AnimationPlayer.new()
	_visual.add_child(animacao)
	var lib := AnimationLibrary.new()
	for clip in dados:
		var info: Dictionary = dados[clip]
		var anim := Animation.new()
		anim.length = info["duration"]
		anim.loop_mode = Animation.LOOP_NONE if clip == "LayToIdle" else Animation.LOOP_LINEAR
		var quadros: Array = info["frames"]
		for id in quadros[0]["rotations"]:
			var trilha := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(trilha, NodePath("Skeleton3D:" + id))
			for i in quadros.size():
				var q: Array = quadros[i]["rotations"][id]
				anim.rotation_track_insert_key(trilha, float(i) / (quadros.size() - 1) * anim.length,
						Quaternion(q[0], q[1], q[2], q[3]))
		var tp := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(tp, NodePath("Skeleton3D:pelvis"))
		for i in quadros.size():
			var v: Array = quadros[i]["hips"]
			anim.position_track_insert_key(tp, float(i) / (quadros.size() - 1) * anim.length,
					Vector3(v[0], v[1], v[2]) * ESTATURA)
		var raiz := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(raiz, NodePath("Skeleton3D:root"))
		anim.position_track_insert_key(raiz, 0, Vector3.ZERO)
		var raiz_r := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(raiz_r, NodePath("Skeleton3D:root"))
		anim.rotation_track_insert_key(raiz_r, 0, Quaternion.IDENTITY)
		lib.add_animation(clip, anim)
	animacao.add_animation_library("", lib)
	animacao.play("Jog_Fwd_Loop")
