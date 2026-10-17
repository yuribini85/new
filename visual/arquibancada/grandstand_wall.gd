extends Node3D
signal impacted(at: Vector3,speed: float)
var impact_emitted := false
var solid: StaticBody3D
var sensor: Area3D
var visible_wall: MeshInstance3D
var cracked := false
var broken := false
var pieces: Array[RigidBody3D] = []
func box_mesh(size: Vector3,at: Vector3,parent: Node3D,tint: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = at
	return mesh
func collision(parent: Node3D,size: Vector3,at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	parent.add_child(shape)
	shape.position = at
func _ready() -> void:
	solid = StaticBody3D.new()
	solid.collision_layer = 2
	solid.collision_mask = 5
	add_child(solid)
	collision(solid,Vector3(2,1.3,.70),Vector3(0,.65,0))
	visible_wall = box_mesh(Vector3(2,1.3,.70),Vector3(0,.65,0),solid,Color("797a6d"))
	sensor = Area3D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 4
	add_child(sensor)
	collision(sensor,Vector3(2.05,1.6,1.5),Vector3(0,.8,0))
func _physics_process(dt: float) -> void:
	if broken: return
	for other in sensor.get_overlapping_bodies():
		if not other is RigidBody3D: continue
		var vehicle_shape := other.find_child("CollisionShape3D",true,false) as CollisionShape3D
		if vehicle_shape == null: continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = vehicle_shape.shape
		query.transform = vehicle_shape.global_transform
		query.transform.origin += other.linear_velocity*dt
		query.collision_mask = 2
		query.margin = .005
		var contact := false
		for hit in get_world_3d().direct_space_state.intersect_shape(query,16):
			contact = contact or hit.collider == solid
		if not contact: continue
		var speed := absf(other.linear_velocity.dot(global_basis.z))
		if speed > 2 and not impact_emitted:
			impact_emitted = true
			impacted.emit(global_position,speed)
		if speed > 2 and not cracked:
			cracked = true
			for side in [-1,1]:
				for j in range(3):
					var mark := box_mesh(Vector3(.025,.42,.009),Vector3((j-1)*.18,.28+j*.34,side*.356),solid,Color("393b35"))
					mark.rotation.z = .4 if j%2 == 0 else -.4
		if speed > 9: fracture()
func fracture() -> void:
	if broken: return
	broken = true
	solid.hide()
	for child in solid.get_children():
		if child is CollisionShape3D: child.set_deferred("disabled",true)
	for column in range(5):
		var left := -1.0+column*.4
		var right := left+.4
		for row in range(4):
			var bottom_l := 0.0 if row == 0 else row*.325+.055*sin(column*1.7+row)
			var bottom_r := 0.0 if row == 0 else row*.325+.055*sin((column+1)*1.7+row)
			var top_l := 1.3 if row == 3 else (row+1)*.325+.055*sin(column*1.7+row+1)
			var top_r := 1.3 if row == 3 else (row+1)*.325+.055*sin((column+1)*1.7+row+1)
			var polygon: Array = [Vector2(left,bottom_l),Vector2(right,bottom_r),Vector2(right,top_r),Vector2(left,top_l)]
			var center := Vector3((left+right)*.5,(bottom_l+bottom_r+top_l+top_r)*.25,0)
			var points := PackedVector3Array()
			for z in [-.35,.35]:
				for v in polygon: points.append(Vector3(v.x,v.y,z)-center)
			var hull := ConvexPolygonShape3D.new()
			hull.points = points
			var body := RigidBody3D.new()
			body.mass = 160
			body.collision_layer = 2
			body.collision_mask = 7
			body.continuous_cd = true
			body.linear_damp = .8
			body.angular_damp = .9
			var friction := PhysicsMaterial.new()
			friction.friction = .9
			body.physics_material_override = friction
			add_child(body)
			body.position = center
			var cs := CollisionShape3D.new()
			cs.shape = hull
			body.add_child(cs)
			var mesh := MeshInstance3D.new()
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
				var normal := (points[face[1]]-points[face[0]]).cross(points[face[2]]-points[face[0]]).normalized()
				for index in [face[0],face[1],face[2],face[0],face[2],face[3]]:
					builder.set_normal(normal)
					builder.add_vertex(points[index])
			mesh.mesh = builder.commit()
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("797a6d")
			material.roughness = 1
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = material
			body.add_child(mesh)
			pieces.append(body)
