extends Node3D
# Batched spectators: seven draw batches per module, no physics bodies.
@export_enum("Meio vazio", "Semi cheio", "Cheio") var occupancy := 1
@export var crowd_seed := 31
var people: Array[Dictionary] = []
var batches: Dictionary = {}
var clock := 0.0
var cheer_start := -100.0
var wave_start := -100.0
var pose_origin := Vector3.ZERO
var pose_basis := Basis.IDENTITY
var current_panic := false
func flee_from(at: Vector3,exit_at: Vector3) -> void:
	var queue_slot := 0
	for p in people:
		if p.has("escape_path") or to_global(p.origin).distance_to(at) > 4.8: continue
		p.panic_start = clock+p.delay*.12
		p.run_speed = 3.1+fmod(p.phase,1.2)
		p.escape_delay = clock+.35+p.delay*.20+queue_slot*.11
		queue_slot += 1
		var start: Vector3 = p.origin
		var exit_local := to_local(exit_at)
		_fugindo = true
		p.escape_path = [start,Vector3(start.x,start.y,start.z+.23),Vector3(2.5,start.y,start.z+.23),Vector3(2.5,.30,.12),Vector3(exit_local.x-.9,.30,.12),Vector3(exit_local.x,.30,.45),Vector3(exit_local.x,-global_position.y+.06,2.70),Vector3(exit_local.x+1,-global_position.y+.06,7.0)]
func fleeing_count() -> int:
	var n := 0
	for p in people:
		if p.has("escape_path"): n += 1
	return n
func escape_position(p: Dictionary) -> Vector3:
	var travel: float = maxf(0,clock-p.escape_delay-.30)*p.run_speed
	var path: Array = p.escape_path
	for j in range(path.size()-1):
		var distance: float = path[j].distance_to(path[j+1])
		if travel < distance: return path[j].lerp(path[j+1],travel/maxf(distance,.001))
		travel -= distance
	return path[-1]+Vector3(0,0,travel)

func start_wave(delay: float = 0.0) -> void:
	cheer_start = -100.0
	wave_start = clock+delay
func wave_count() -> int:
	var count := 0
	for p in people:
		var t: float = clock-wave_start-(p.origin.x+2.60)/.61*.22-p.delay*.06
		if t > .15 and t < 1.2: count += 1
	return count
var colors := [Color("874d36"),Color("a39775"),Color("4e6970"),Color("5d6450"),Color("845f55"),Color("bbb29b")]
var skins := [Color("ba8a67"),Color("805943"),Color("d1ad8c"),Color("614537")]
func _ready() -> void:
	rebuild(occupancy)
func mesh_for(kind: String) -> Mesh:
	if kind == "head":
		var s := SphereMesh.new()
		s.radius = .105
		s.height = .24
		s.radial_segments = 8
		s.rings = 4
		return s
	var b := BoxMesh.new()
	b.size = {"torso":Vector3(.32,.43,.20),"hips":Vector3(.27,.16,.19),"arm":Vector3(.095,1,.095),"leg":Vector3(.13,1,.14),"shoe":Vector3(.14,.085,.25),"hair":Vector3(.19,.075,.18)}[kind]
	return b
func rebuild(level: int) -> void:
	occupancy = clampi(level,0,2)
	for b in batches.values():
		remove_child(b)
		b.queue_free()
	batches.clear()
	people.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = crowd_seed
	var seats: Array[Dictionary] = []
	for row in range(5):
		for column in range(8):
			seats.append({"origin":Vector3(-2.60+column*.61,.30+row*.45,.55+row*.85),"rank":rng.randf(),"phase":rng.randf()*TAU,"delay":rng.randf_range(.15,1.15),"style":rng.randi_range(0,2),"shirt":colors[rng.randi_range(0,colors.size()-1)],"skin":skins[rng.randi_range(0,skins.size()-1)],"size":rng.randf_range(.90,1.02)})
	seats.sort_custom(func(a,b): return a.rank < b.rank)
	var count: int = [12,26,40][occupancy]
	for j in range(count): people.append(seats[j])
	for kind in ["torso","hips","head","hair","arm","leg","shoe"]:
		var batch := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh_for(kind)
		mm.instance_count = count*({"arm":4,"leg":4,"shoe":2}.get(kind,1))
		batch.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = .95
		batch.material_override = mat
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(batch)
		batches[kind] = batch
	update_people()
func celebrate() -> void:
	cheer_start = clock
func cheering_count() -> int:
	var n := 0
	for p in people:
		var t: float = clock-cheer_start-p.delay
		if t > .25 and t < 7.8: n += 1
	return n
## Atualizar todos os espectadores a cada quadro custava ~1 ms por bloco
## (12 blocos: ~10 ms). Comemorando, na ola ou fugindo: 20 vezes por segundo;
## sentados (só o balanço do tronco): 5.
const ATIVO_HZ := 20.0
const PARADO_HZ := 5.0
var _desde := 0.0
var _fugindo := false
func _process(dt: float) -> void:
	clock += dt
	_desde += dt
	var ativo := _fugindo or clock - cheer_start < 9.0 or clock - wave_start < 6.0
	if _desde < 1.0 / (ATIVO_HZ if ativo else PARADO_HZ):
		return
	_desde = 0.0
	update_people()
func put(kind: String,index: int,position_local: Vector3,scale_local: Vector3,tint: Color) -> void:
	var mm: MultiMesh = batches[kind].multimesh
	var part_basis := pose_basis
	if kind == "torso" and current_panic: part_basis = part_basis*Basis(Vector3.RIGHT,-.24)
	mm.set_instance_transform(index,Transform3D(part_basis.scaled(scale_local),pose_origin+pose_basis*(position_local-pose_origin)))
	mm.set_instance_color(index,tint)
func segment(kind: String,index: int,a: Vector3,b: Vector3,tint: Color,width: float) -> void:
	var d := b-a
	var axis := d.normalized()
	var helper := Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < .95 else Vector3.RIGHT
	var x := axis.cross(helper).normalized()
	var z := x.cross(axis).normalized()
	var basis := Basis(x*width,axis*d.length(),z*width)
	var mm: MultiMesh = batches[kind].multimesh
	mm.set_instance_transform(index,Transform3D(pose_basis*basis,pose_origin+pose_basis*((a+b)*.5-pose_origin)))
	mm.set_instance_color(index,tint)
func update_people() -> void:
	for i in range(people.size()):
		var p: Dictionary = people[i]
		var t: float = clock-cheer_start-p.delay
		var stand := smoothstep(0,.7,t)*(1-smoothstep(7.0,8.0,t))
		var wave_time: float = clock-wave_start-(p.origin.x+2.60)/.61*.22-p.delay*.06
		var wave_pose := smoothstep(0,.4,wave_time)*(1-smoothstep(.8,1.35,wave_time))
		var doing_wave := wave_pose > .001
		stand = maxf(stand,wave_pose)
		var s: float = p.size
		var origin: Vector3 = p.origin
		var panicking: bool = p.has("panic_start") and clock > p.panic_start
		current_panic = panicking
		var escaping: bool = p.has("escape_path") and clock > p.escape_delay
		if escaping:
			stand = smoothstep(0,.30,clock-p.escape_delay)
			doing_wave = false
			origin = escape_position(p)
		pose_origin = origin
		pose_basis = Basis.IDENTITY
		if escaping:
			p.escape_delay -= .05
			var ahead := escape_position(p)
			p.escape_delay += .05
			var heading := ahead-origin
			if Vector2(heading.x,heading.z).length() > .001:
				pose_basis = Basis(Vector3.UP,atan2(-heading.x,-heading.z))

		var sway := sin(clock*1.6+p.phase)*.015
		if panicking: sway = sin(clock*15+p.phase)*.024
		var pelvis := Vector3(sway,lerpf(.48,.87,stand),lerpf(0,-.30,stand))
		if escaping: pelvis.y += absf(sin(clock*12+p.phase))*.045
		var chest := pelvis+Vector3(0,.29,-.025)
		if panicking: chest += Vector3(0,-.035,-.07)
		put("torso",i,origin+chest*s,Vector3.ONE*s,p.shirt)
		put("hips",i,origin+pelvis*s,Vector3.ONE*s,Color("323b40"))
		var head_shift := Vector3(0,-.04,-.14) if panicking else Vector3.ZERO
		put("head",i,origin+(pelvis+Vector3(sway,.66,-.03)+head_shift)*s,Vector3.ONE*s,p.skin)
		put("hair",i,origin+(pelvis+Vector3(sway,.76,-.005)+head_shift)*s,Vector3.ONE*s,Color("35302a"))
		for side in range(2):
			var sign_x := -1.0 if side == 0 else 1.0
			var hip := pelvis+Vector3(sign_x*.085,-.02,0)
			var knee := Vector3(sign_x*.105,lerpf(.30,.46,stand),-.34)
			var ankle := Vector3(sign_x*.105,.105,-.32)
			var stride := sin(clock*12+p.phase+side*PI)
			if escaping:
				knee += Vector3(0,.13*maxf(0,stride),stride*.20)
				ankle += Vector3(0,.18*maxf(0,stride),stride*.32)
			segment("leg",i*4+side*2,origin+hip*s,origin+knee*s,Color("39434a"),s)
			segment("leg",i*4+side*2+1,origin+knee*s,origin+ankle*s,Color("39434a"),s)
			put("shoe",i*2+side,origin+(Vector3(sign_x*.105,.065,-.39)+(Vector3(0,.18*maxf(0,stride),stride*.32) if escaping else Vector3.ZERO))*s,Vector3.ONE*s,Color("252a2c"))
			var shoulder := pelvis+Vector3(sign_x*.19,.45,0)
			var idle_elbow := pelvis+Vector3(sign_x*.22,.16,-.10)
			var idle_hand := pelvis+Vector3(sign_x*.10,.05,-.30)
			var elbow := idle_elbow
			var hand := idle_hand
			var motion: float = clock*(4.6 if p.style == 0 else 3.0)+p.phase
			if panicking and (not escaping or clock-p.escape_delay < .8 or (p.style == 1 and side == 0)):
				elbow = pelvis+Vector3(sign_x*.27,.43,-.10)
				hand = pelvis+Vector3(sign_x*.10,.68,-.16)
			elif escaping:
				elbow = pelvis+Vector3(sign_x*.21,.20,-.10+stride*.12)
				hand = pelvis+Vector3(sign_x*.15,.30,-.24+stride*.26)
			elif doing_wave:
				elbow = pelvis+Vector3(sign_x*.27,.56,-.04)
				hand = pelvis+Vector3(sign_x*.27,.91,-.06)
			elif p.style == 0:
				elbow = pelvis+Vector3(sign_x*.24,.29,-.14)
				hand = pelvis+Vector3(sign_x*(.045+.075*(1+sin(motion))),.38,-.35)
			elif p.style == 1:
				elbow = pelvis+Vector3(sign_x*.27,.56,-.04)
				hand = pelvis+Vector3(sign_x*.23,.83+.07*sin(motion+side),-.10)
			else:
				if side == 0:
					elbow = pelvis+Vector3(sign_x*.25,.48,-.10)
					hand = pelvis+Vector3(sign_x*.20,.75+.13*sin(motion),-.18)
			var arm_blend := 1.0 if panicking else stand
			elbow = idle_elbow.lerp(elbow,arm_blend)
			hand = idle_hand.lerp(hand,arm_blend)
			segment("arm",i*4+side*2,origin+shoulder*s,origin+elbow*s,p.shirt,s)
			segment("arm",i*4+side*2+1,origin+elbow*s,origin+hand*s,p.skin,s)
