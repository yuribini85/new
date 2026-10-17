extends PhysicalBone3D
## Osso do ragdoll do piloto (pacote de dano): segura picos do solver quando o
## carro pesado acerta os membros leves.


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.angular_velocity = state.angular_velocity.limit_length(12.0)
	state.linear_velocity = state.linear_velocity.limit_length(16.0)
