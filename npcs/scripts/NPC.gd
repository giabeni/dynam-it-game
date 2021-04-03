extends KinematicBody

enum States {
	EXPLORING,
	FOLLOWING,
	DEAD
}

onready var controller = $AIController
onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var bomb: Bomb
onready var bomb_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Bomb
onready var smoke_particles: Particles = $SmokeParticles
onready var footsteps = $Footsteps
onready var target_detection_area: Area = $TargetDetectionArea
onready var bomb_trigger_area: Area = $BombTriggerArea
onready var sight_origin: Position3D = $CharacterArmature/SightOrigin
onready var body_hitpoint: Position3D = $CharacterArmature/BodyHitpoint

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")

var has_bomb = false
var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var available_bombs: int = 1
var state = States.EXPLORING
var is_escaping_from_bomb = false

func _ready():
	if available_bombs > 0:
		_spawn_bomb()
	

func _physics_process(delta):
	_set_animations(delta)
	

func _spawn_bomb():
	bomb = BOMB_SCENE.instance()
	bomb_loc.call_deferred("add_child", bomb)
	target_blend_carry = 1
	bomb.connect("bomb_exploded", self, "_on_bomb_exploded")
	has_bomb = true
	
func is_alive():
	return state in [States.EXPLORING, States.FOLLOWING]


func _set_animations(delta):
	
	if is_alive():
		anim_tree.set("parameters/DeadOrAlive/current", 0)
		
		var h_velocity: Vector2 = Vector2(controller.velocity.x, controller.velocity.z)
		var vel_factor = h_velocity.length() / controller.RUN_SPEED
		anim_tree.set("parameters/BlendRun/blend_position", vel_factor)
		anim_tree.set("parameters/BlendRunCarry/blend_position", vel_factor)
		
		if should_drop_bomb:
			target_blend_carry = 0
			if blend_carry <= 0.1:
				should_drop_bomb = false
				footsteps.enabled = false
				_on_bomb_dropped()
				
		footsteps.enabled = vel_factor > 0.05
		
		blend_carry = lerp(blend_carry, target_blend_carry, delta * 6)
		anim_tree.set("parameters/BlendCarry/blend_amount", blend_carry)
		
	elif state == States.DEAD:
#		print("dead: ", anim_tree.get("parameters/DeadOrAlive/current"))
		anim_tree.set("parameters/DeadOrAlive/current", 1)
		
		

func _can_drop_bomb():
	return has_bomb

	
func _on_bomb_dropped():
	has_bomb = false
	if available_bombs > 0:
		_spawn_bomb()


func _on_bomb_exploded():
	available_bombs += 1
	_spawn_bomb()


func _drop_bomb():
	bomb.drop()
	should_drop_bomb = true
	available_bombs -= 1
	

func on_explosion_hit():
	if is_alive():
		print(name, "  DIED!!!!")
		smoke_particles.emitting = true
		state = States.DEAD
		controller.set_physics_process(false)
		$TargetDetectionTimer.stop()
		$BombIntervalTimer.stop()
		$BombDetectionTimer.stop()
		$BombEscapeTimer.stop()
	

func _get_random_target_point():
	var aim_vector = self.global_transform.basis.z
	var random_angle = rand_range(0, 360)
	var aim_range = 10
	var world_point = global_transform.rotated(Vector3.UP, deg2rad(random_angle)).translated(aim_vector * aim_range).origin
	var nav_point = controller.navigation.get_closest_point(world_point)
	return nav_point


func _get_run_away_point(from: Vector3):
	var direction = global_transform.origin - from
	var offset = 25
	var world_point = global_transform.origin + direction.normalized() * offset
	var nav_point = controller.navigation.get_closest_point(world_point)
	return nav_point


func _on_TargetDetectionTimer_timeout():
	if is_escaping_from_bomb:
		return
	
	var found_target = false
	var space = get_world().direct_space_state
	for body in target_detection_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id() and body.is_in_group("Miners"):
			var hitpoint = body.global_transform.origin if not "body_hitpoint" in body else body.body_hitpoint.global_transform.origin
			var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
			if not ray.empty() and ray.collider.get_instance_id() != self.get_instance_id():
				if ray.collider.is_in_group("Miners") and ray.collider.is_alive():
					print("target found: ", body)
					found_target = true
					controller.target = body
					state = States.FOLLOWING
	
	if not found_target:
		var random_point = _get_random_target_point()
		controller.move_to(random_point)
		print("random target", random_point)
		state = States.EXPLORING
		
				
func _on_BombIntervalTimer_timeout():
	for body in bomb_trigger_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id() and body.is_in_group("Miners") and body.is_alive():
			# if gets close to another miner, drops a bomb
			if _can_drop_bomb():
				_drop_bomb()


func _on_BombDetectionTimer_timeout():
	for body in bomb_trigger_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id() and body.is_in_group("Bombs") and body.is_dropped():
			# if notice a bomb, try to escape 
			var escape_point = _get_run_away_point(body.global_transform.origin)
			controller.move_to(escape_point)
			$BombEscapeTimer.start()
			print("Escaping!!!!! ", escape_point)
			is_escaping_from_bomb = true


func _on_BombEscapeTimer_timeout():
	print("No escape.")
	is_escaping_from_bomb = false
	


func _on_ForgetTargetTimer_timeout():
	if is_instance_valid(controller.target) and not controller.target.is_alive():
		controller.target = null
		var random_point = _get_random_target_point()
		controller.move_to(random_point)
		print("forgot target", random_point)
		state = States.EXPLORING
