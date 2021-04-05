extends RigidBody

class_name Bomb

signal bomb_exploded

onready var timer: Timer = $Timer
onready var spark1: Particles = $Sparks/Spark
onready var spark2: Particles = $Sparks/Spark2
onready var spark3: Particles = $Sparks/Spark3
onready var sparks: Spatial = $Sparks
onready var light: OmniLight = $Light
onready var explosion: Particles = $Explosion
onready var explosion2: Particles = $Explosion2
onready var mesh = $tnt_pile
onready var explosion_area = $DamageArea
onready var anim_player: AnimationPlayer = $AnimationPlayer

enum State {
	CARRY,
	DROPPED,
	EXPLODED
}

var state = State.CARRY

var is_from_player = false
var bomb_range = 5

func _ready():
	pass
	

func _physics_process(delta):
	if state == State.DROPPED:
		sparks.translate(Vector3.RIGHT * delta * 0.025)

func drop():
	set_as_toplevel(true)
	mass = 20
	mode = MODE_RIGID
	state = State.DROPPED
	timer.start()
	anim_player.play("Drop")
	light.light_energy = 1.5
	yield(get_tree().create_timer(1), "timeout")
	$Range.show()


func _explode():
	state = State.EXPLODED
	$Range.hide()	
	mesh.hide()
	sparks.hide()
	anim_player.play("Explode")
	emit_signal("bomb_exploded")
	


func _on_Timer_timeout():
	_explode()


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
					

func _on_DamageArea_body_entered(body: Spatial):
	if state != State.EXPLODED:
		return
		
	if body.has_method("on_explosion_hit"):
		var space = get_world().direct_space_state
		var hitpoint = body.global_transform.origin if not "body_hitpoint" in body else body.body_hitpoint.global_transform.origin
		var ray_collision = space.intersect_ray(global_transform.origin, hitpoint, [], 1)
#		print("Ray bomb:  ", ray_collision)
		if not ray_collision.empty() and ray_collision.collider.get_instance_id() == body.get_instance_id():
			body.on_explosion_hit()
		# case collide with bomb that player is holding
		elif not ray_collision.empty() and "bomb" in body and is_instance_valid(body.bomb) and ray_collision.collider.get_instance_id() == body.bomb.get_instance_id():
			body.on_explosion_hit()
			
	if body.has_method("destroy"):
		var space = get_world().direct_space_state
		var hitpoint = body.global_transform.origin if not "hitpoint" in body else body.hitpoint.global_transform.origin
		var ray_collision = space.intersect_ray(global_transform.origin, hitpoint, [], 1)
#		print("Ray bomb:  ", ray_collision)
		if not ray_collision.empty() and ray_collision.collider.get_instance_id() == body.get_instance_id():
			body.destroy()
	
	

func _on_animation_finished(anim_name):
	if anim_name == "Explode":
		call_deferred("queue_free")
		
func is_dropped():
	return state == State.DROPPED
	
func set_range(amount):
	bomb_range = amount
	if is_instance_valid(explosion_area):
		explosion_area.get_node("DamageCollisionShape").shape.radius  = amount
	$Range.radius = amount
		
