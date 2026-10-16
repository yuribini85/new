extends StaticBody3D
@export var left_end := false
@export var right_end := false
@export_enum("Meio vazio", "Semi cheio", "Cheio") var occupancy := 1
@export var crowd_seed := 31
@export var elevation := 1.25
@export var front_wall := true
var wall_sections: Array[Node3D] = []
var crowd: Node3D
func _ready() -> void:
	for part in get_children():
		if part is Node3D: part.position.y += elevation
	for x in [-2.7,0,2.7]:
		for z in [.70,4.10]:
			var support := MeshInstance3D.new()
			var shape := BoxMesh.new()
			shape.size = Vector3(.15,elevation,.15)
			support.mesh = shape
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("38423f")
			support.material_override = mat
			add_child(support)
			support.position = Vector3(x,elevation*.5,z)
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = shape.size
			collider.shape = box
			add_child(collider)
			collider.position = support.position
	if right_end:
		for step in range(6):
			var step_height := (elevation+.30)*float(step+1)/6.0
			var stair := MeshInstance3D.new()
			var shape := BoxMesh.new()
			shape.size = Vector3(.85,step_height,.45)
			stair.mesh = shape
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("686b60")
			stair.material_override = mat
			add_child(stair)
			stair.position = Vector3(3.43,step_height*.5,2.70-step*.45)
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = shape.size
			collider.shape = box
			add_child(collider)
			collider.position = stair.position
		var landing := MeshInstance3D.new()
		var landing_mesh := BoxMesh.new()
		landing_mesh.size = Vector3(.85,.14,.85)
		landing.mesh = landing_mesh
		add_child(landing)
		landing.position = Vector3(3.43,elevation+.23,.45)
		var landing_collision := CollisionShape3D.new()
		var landing_shape := BoxShape3D.new()
		landing_shape.size = landing_mesh.size
		landing_collision.shape = landing_shape
		add_child(landing_collision)
		landing_collision.position = landing.position
	if front_wall:
		for index in range(3):
			var section: Node3D = load("res://visual/arquibancada/grandstand_wall.gd").new()
			add_child(section)
			section.position = Vector3(-2+index*2,0,-.65)
			wall_sections.append(section)
	for pair in [["LeftEnd",left_end],["RightEnd",right_end]]:
		var cap: Node3D = get_node(pair[0])
		cap.visible = pair[1]
		for shape in cap.find_children("*","CollisionShape3D",true,false):
			shape.disabled = not pair[1]
	if right_end:
		# Open the side landing; the staircase now approaches from +Z (rear).
		for part in get_node("RightEnd").get_children():
			if str(part.name).begins_with("RightEndRail0") or str(part.name).begins_with("RightEndPost0"):
				if part is GeometryInstance3D: part.hide()
				if part is CollisionShape3D: part.disabled = true
	crowd = load("res://visual/arquibancada/spectator_crowd.gd").new()
	crowd.occupancy = occupancy
	crowd.crowd_seed = crowd_seed
	add_child(crowd)
	crowd.position.y = elevation
func set_occupancy(level: int) -> void:
	occupancy = clampi(level,0,2)
	if is_instance_valid(crowd): crowd.rebuild(occupancy)
func celebrate() -> void:
	if is_instance_valid(crowd): crowd.celebrate()
func start_wave(delay: float = 0.0) -> void:
	if is_instance_valid(crowd): crowd.start_wave(delay)
