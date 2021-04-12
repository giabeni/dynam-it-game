extends Destructible

enum State {
	IDLE,
	EXPLODED,
}

export var state = State.IDLE


onready var explosion: Particles = $Explosion
onready var explosion2: Particles = $Explosion2
onready var mesh = $tnt_pile
onready var explosion_area = $DamageArea
onready var anim_player: AnimationPlayer = $AnimationPlayer

func _do_damage():
	if state != State.EXPLODED:
		return
	
	for body in explosion_area.get_overlapping_bodies():
#		print("\nbody in tnt: ", body, "groups: ", body.get_groups())
		if body.has_method("on_explosion_hit"):
			var space = get_world().direct_space_state
			var hitpoint = body.global_transform.origin if not "body_hitpoint" in body else body.body_hitpoint.global_transform.origin
			var ray_origin = global_transform.origin + Vector3.UP * 0
			var ray_collision = space.intersect_ray(ray_origin, hitpoint, [], 1)
#			print("Ray bomb to MINER:  ", ray_collision)
			if not ray_collision.empty() and ray_collision.collider.get_instance_id() == body.get_instance_id():
				body.on_explosion_hit()
			# case collide with bomb that player is holding
			elif not ray_collision.empty() and "bomb" in body and is_instance_valid(body.bomb) and ray_collision.collider.get_instance_id() == body.bomb.get_instance_id():
				body.on_explosion_hit()
				
		if body.has_method("destroy"):
			var space = get_world().direct_space_state
			for hit_pos in body.hitpoints.get_children():
				var hitpoint = hit_pos.global_transform.origin
				var ray_origin = global_transform.origin + Vector3.UP * 0
				var ray_collision = space.intersect_ray(ray_origin, hitpoint, [], 1)
				if "collider" in ray_collision:
#					print("TNT IN OBSTACLE!: ", ray_collision.collider.get_instance_id() == body.get_instance_id())
					if not ray_collision.empty() and ray_collision.collider.get_instance_id() == body.get_instance_id():
#						print("Ray bomb to TNT:  ", ray_collision.collider.name)
						body.destroy()
						
					
