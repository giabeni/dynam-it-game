extends KinematicBody

enum States {
	EXPLORING,
	FOLLOWING,
	DEAD
}

onready var controller = $AIController
onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var bomb_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Bomb
onready var weapon_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Weapon
onready var smoke_particles: Particles = $SmokeParticles
onready var footsteps = $Footsteps
onready var target_detection_area: Area = $TargetDetectionArea
onready var bomb_trigger_area: Area = $BombTriggerArea
onready var sight_origin: Position3D = $CharacterArmature/SightOrigin
onready var body_hitpoint: Position3D = $CharacterArmature/BodyHitpoint
onready var breath_sound: AudioStreamPlayer3D = $BreathSound
onready var weapon_timer: Timer = $WeaponTimer

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")
export(PackedScene) var GOLD_SCENE = preload("res://powerups/scenes/GoldBar.tscn")
export(PackedScene) var PICKAXE_SCENE = preload("res://weapons/scenes/Pickaxe.tscn")

var bomb: Bomb
var weapon: Weapon
var has_bomb = false
var has_weapon = false
var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var state = States.EXPLORING
var is_escaping_from_bomb = false
var gold = 0
var wall_position = Vector3(0, 0, 0)
var bomb_range = 5
var max_bombs: int = 1
var dropped_bombs: int = 0

signal on_died

func _ready():
	if max_bombs > 0:
		_spawn_bomb()
	

func _physics_process(delta):
	_set_animations(delta)
	
	if controller.velocity.length() <= 0.1:
#		print("on wall")
		$OnWallTimer.start()
		wall_position = global_transform.origin

func _spawn_bomb():
	if has_weapon:
		return
	bomb = BOMB_SCENE.instance()
	bomb.set_range(bomb_range)
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
	return has_bomb and dropped_bombs < max_bombs and not has_weapon

	
func _on_bomb_dropped():
	has_bomb = false
	if dropped_bombs < max_bombs and not has_bomb:
		_spawn_bomb()


func _on_bomb_exploded():
	dropped_bombs -= 1
	if dropped_bombs < max_bombs and not has_bomb:
		_spawn_bomb()


func _drop_bomb():
	bomb.drop()
	should_drop_bomb = true
	dropped_bombs += 1

	# Escape from own bomb
	var escape_point = _get_run_away_point(bomb.global_transform.origin)
	controller.move_to(escape_point)
	$BombEscapeTimer.start()
#			print("Escaping!!!!! ", escape_point)
	is_escaping_from_bomb = true
	

func on_explosion_hit():
	if is_alive():
#		print(name, "  DIED!!!!")
		breath_sound.stop()
		smoke_particles.emitting = true
		state = States.DEAD
		_drop_gold()
		emit_signal("on_died")
		controller.set_physics_process(false)
		$TargetDetectionTimer.stop()
		$BombIntervalTimer.stop()
		$BombDetectionTimer.stop()
		$BombEscapeTimer.stop()
		$OnWallTimer.stop()
		
func _drop_gold():
	if gold > 0:
		var offset = Vector3(0, 0, 0)
		while gold > 0:
			var item = GOLD_SCENE.instance()
			item.global_transform.origin = self.global_transform.origin + offset
			get_parent().call_deferred("add_child", item)
#			print(name, " dropped gold! <<<<<<  ", item.name, " \n\n")
			gold -= 1
			offset += Vector3(0.8, 0, 0.8)
	

func _get_random_target_point():
	var aim_vector = (self.global_transform.basis.z + Vector3.UP * 2).rotated(Vector3.LEFT, deg2rad(15))
	var random_angle = rand_range(0, 360)
	var aim_range = 10
	var world_point = global_transform.rotated(Vector3.UP, deg2rad(random_angle)).translated(aim_vector * aim_range).origin
	var nav_point = controller.navigation.get_closest_point(world_point)
	return nav_point


func _get_run_away_point(from: Vector3):
	var found_point = false
	var tries = 5
	var min_distance = 5
	
	while not found_point:
		var direction = global_transform.origin - from
		var offset = 10
		var world_point = global_transform.origin + direction.normalized() * offset
		var nav_point = controller.navigation.get_closest_point(world_point)
		if abs((nav_point - from).length()) < min_distance or tries <= 0:
			return nav_point
		else:
			tries -= 1
			


func _on_TargetDetectionTimer_timeout():
	if is_escaping_from_bomb or not is_alive():
		
#		if name == "NPC6":
#			print("NPC 6: \t - escaping from: BOMB - ")
		return
	
	var found_miner = false
	var found_obstacle = false
	var found_item = false
	var space = get_world().direct_space_state
	for body in target_detection_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id():
			if body.is_in_group("Items"):
				var hitpoint = body.hitpoint.global_transform.origin
				var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
				if not ray.empty() and ray.collider.get_instance_id() != self.get_instance_id():
					if ray.collider.is_in_group("Items"):
						found_item = true
						controller.target = body
						state = States.FOLLOWING
#						if name == "NPC6":
#							print("NPC 6: \t - new target: ITEM - ", body.name)
						return
						
			elif body.is_in_group("Miners") and not found_item:
				var hitpoint = body.global_transform.origin if not "body_hitpoint" in body else body.body_hitpoint.global_transform.origin
				var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
				if not ray.empty() and ray.collider.get_instance_id() != self.get_instance_id():
					if ray.collider.is_in_group("Miners") and ray.collider.is_alive():
						found_miner = true
						controller.target = body
						state = States.FOLLOWING
#						if name == "NPC6":
#							print("NPC 6: \t - new target: MINER - ", body.name)
						return
						
#						print("Miner target found : ", body)
						
			elif body.is_in_group("Obstacles") and not found_miner and not found_item:
				for hit_pos in body.hitpoints.get_children():
					var hitpoint = hit_pos.global_transform.origin
					var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
					if not ray.empty() and ray.collider.get_instance_id() != self.get_instance_id():
						if ray.collider.is_in_group("Obstacles"):
							found_obstacle = true
							controller.target = body
							state = States.FOLLOWING
#							if name == "NPC6":
#								print("NPC 6: \t - new target: OBSTACLE - ", body.name)
							return
#							print("Obstacle target found : ", body)
			
	
	if not found_miner and not found_obstacle and not found_item:
		var random_point = _get_random_target_point()
		controller.move_to(random_point)
#		print("random target", random_point)
		state = States.EXPLORING
#		if name == "NPC6":
#			print("NPC 6: \t - new target: RANDOM - ", random_point)
		
				
func _on_BombIntervalTimer_timeout():
	if not is_alive():
		return
	for body in bomb_trigger_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id():
			if (body.is_in_group("Miners") and body.is_alive()) or body.is_in_group("Obstacles"):
				# if gets close to target, drops a bomb
				if _can_drop_bomb():
					_drop_bomb()
				elif has_weapon:
					_attack()


func _on_BombDetectionTimer_timeout():
	for body in bomb_trigger_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id() and body.is_in_group("Bombs") and body.is_dropped():
			# if notice a bomb, try to escape 
			var escape_point = _get_run_away_point(body.global_transform.origin)
			controller.move_to(escape_point)
			$BombEscapeTimer.start()
#			print("Escaping!!!!! ", escape_point)
			is_escaping_from_bomb = true


func _on_BombEscapeTimer_timeout():
#	print("No escape.")
	is_escaping_from_bomb = false
	


func _on_ForgetTargetTimer_timeout():
	if not is_alive():
		return

	if controller.target != null:
		if is_instance_valid(controller.target) and controller.target.is_in_group("Miners") and not controller.target.is_alive():
			controller.target = null
			var random_point = _get_random_target_point()
			controller.move_to(random_point)
#			if name == "NPC6":
#				print("NPC 6: \t - forgot miner target ", random_point)
			state = States.EXPLORING
		elif is_instance_valid(controller.target) and controller.target.is_in_group("Obstacles") and controller.target.destroyed:
			controller.target = null
			var random_point = _get_random_target_point()
			controller.move_to(random_point)
#			if name == "NPC6":
#				print("NPC 6: \t - forgot obstacle target ", random_point)
			state = States.EXPLORING
		elif is_instance_valid(controller.target) and controller.target.is_in_group("Items"):
			return
		else:
			return
#			controller.target = null
#			var random_point = _get_random_target_point()
#			controller.move_to(random_point)
#			if name == "NPC6":
#				print("NPC 6: \t - forgot else target ", random_point)
#			state = States.EXPLORING
			
func on_gold_collected():
	gold += 1
#	print(name, " collected ", str(gold), " kg of gold!")
		


func _on_OnWallTimer_timeout():
	if global_transform.origin.distance_to(wall_position) < 1 and is_alive():
		var random_point = _get_random_target_point()
		controller.move_to(random_point)
		
#		if name == "NPC6":
#			print("NPC 6: \t - on WALL - ", random_point)
		state = States.EXPLORING


func on_powerup_collected(type, amount):
	if type == "VELOCITY":
		controller.RUN_SPEED += amount
	elif type == "BOMB_RANGE":
		bomb_range += amount
		if is_instance_valid(bomb):
			bomb.set_range(bomb_range)
	elif type == "EXTRA_BOMB":
		max_bombs += 1
		

func _get_weapon_scene(type: String):
	match type:
		"PICKAXE":
			return PICKAXE_SCENE


func on_weapon_collected(type: String):
	has_weapon = true
	weapon = _get_weapon_scene(type).instance()
	weapon.equip(self)
	
	target_blend_carry = 0
	has_bomb = false
	if bomb_loc.get_child_count() > 0:
		bomb_loc.get_children()[0].hide()
		bomb_loc.get_children()[0].call_deferred("queue_free")

	if is_instance_valid(bomb):
		bomb.hide()
		bomb.call_deferred("queue_free")
		
	if weapon_loc.get_child_count() > 0:
		weapon_loc.get_children()[0].hide()
		weapon_loc.get_children()[0].call_deferred("queue_free")
		
	weapon_loc.call_deferred("add_child", weapon)
	weapon_timer.start(weapon.DURATION)
		
func on_weapon_hit():
	breath_sound.stop()
	$HurtSound2.play()
	state = States.DEAD
	emit_signal("on_died")
	controller.set_physics_process(false)
	

func _attack():
	if has_weapon and is_instance_valid(weapon):
		weapon.start_attack(1.042, 0.27)
		anim_tree.set("parameters/Slash/active", true)


func _on_WeaponTimer_timeout():
	if is_instance_valid(weapon):
		weapon.call_deferred("queue_free")
		has_weapon = false
		if dropped_bombs < max_bombs and not has_bomb:
			_spawn_bomb()
