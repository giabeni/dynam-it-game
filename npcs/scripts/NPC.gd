extends KinematicBody

enum States {
	EXPLORING,
	FOLLOWING,
	DEAD,
	PAUSED,
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
onready var hurt_sound: AudioStreamPlayer3D = $HurtSound
onready var weapon_timer: Timer = $WeaponTimer
onready var bomb_interval_timer: Timer = $BombIntervalTimer
onready var random_following_timer: Timer = $RandomFollowingTimer
onready var skeleton: Skeleton = $CharacterArmature/Skeleton

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")
export(PackedScene) var GOLD_SCENE = preload("res://powerups/scenes/GoldBar.tscn")
export(PackedScene) var PICKAXE_SCENE = preload("res://weapons/scenes/Pickaxe.tscn")
export(PackedScene) var MINIAXE_SCENE = preload("res://weapons/scenes/MiniAxe.tscn")
export(NodePath) var NAV_GRID_PATH = null
export(float) var MIN_IMPACT_TO_BE_DIZZY = 2000
export var paused = true

var inner_area: Area 
var bomb: Bomb
var weapon: Weapon
var has_bomb = false
var has_weapon = false
var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var state = States.EXPLORING
var is_escaping_from_bomb = false
var is_dizzy = false
var time_to_die = 0
var impulse = Vector3.ZERO
var escape_point = Vector3.INF
var gold = 0
var wall_position = Vector3(0, 0, 0)
var bomb_range = 2.5
var max_bombs: int = 1
var dropped_bombs: int = 0
var gold_piles: Spatial
var obstacles: Spatial
var player: KinematicBody

signal on_died
signal found_escape_point

func _ready():
	if NAV_GRID_PATH:
		controller.navigation = get_node(NAV_GRID_PATH)
	
	if max_bombs > 0:
		_spawn_bomb()
		
	if randf() < 0.1:
		on_weapon_collected("MINIAXE")
		
	if paused:
		set_paused(true)
		
	if has_node("InnerArea"):
		inner_area = get_node("InnerArea")
		

func set_paused(paused):
	if paused:
		state = States.PAUSED
	else:
		state = States.EXPLORING
		
	set_physics_process(not paused)
	set_physics_process_internal(not paused)
	set_process(not paused)
	set_process_internal(not paused)
	

func _physics_process(delta):
	_set_animations(delta)
	
	if controller.velocity.length() <= 0.1:
#		print("on wall")
		$OnWallTimer.start()
		wall_position = global_transform.origin
		
	if not is_alive():
		var vel = Vector3.DOWN * controller.GRAVITY + impulse * delta
		if impulse != Vector3.ZERO:
			impulse = lerp(impulse, Vector3.ZERO, delta * controller.ACCELERATION)
#		print("Vel = ", vel)
		move_and_slide(vel, Vector3.UP)


func _spawn_bomb():
	if has_weapon:
		return
	bomb = BOMB_SCENE.instance()
	bomb.set_range(bomb_range)
	bomb_loc.add_child(bomb)
	target_blend_carry = 1
	bomb.connect("bomb_exploded", self, "_on_bomb_exploded")
	bomb_interval_timer.wait_time = 1
	bomb_interval_timer.start()
	has_bomb = true
	
func is_alive():
	return state in [States.EXPLORING, States.FOLLOWING]


func _set_animations(delta):
	
	if is_alive():
		anim_tree.set("parameters/DeadOrAlive/current", 0 if not is_dizzy else 2)
		
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
		if time_to_die > 0:
			yield(get_tree().create_timer(time_to_die), "timeout")
		anim_tree.set("parameters/DeadOrAlive/current", 1)
	
	_set_weapon_color(delta)
		
		

func _can_drop_bomb():
	return has_bomb and dropped_bombs < max_bombs and not has_weapon and not is_dizzy
		

func _can_attack():
	return has_weapon and not has_bomb and not is_dizzy and is_instance_valid(weapon) and not weapon.THROWABLE


func _can_throw():
	if has_bomb or is_dizzy:
		return false
	if has_weapon and is_instance_valid(weapon) and weapon.THROWABLE:
		return true
		

func _set_weapon_color(delta):
	if has_weapon and is_instance_valid(weapon) and weapon.TYPE == "MINIAXE":
		if bomb_interval_timer.time_left <= 2:
			weapon.outline.show()
			var outline_color = lerp(weapon.outline_color, Color.red, 2 - bomb_interval_timer.time_left)
			weapon.set_outline_color(outline_color)
		else:
			weapon.outline.hide()
			weapon.set_outline_color(Color.white)


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
	_get_run_away_point(bomb.global_transform.origin)
	yield(self, "found_escape_point")
	controller.move_to(escape_point)
	$BombEscapeTimer.start()
#			print("Escaping!!!!! ", escape_point)
	is_escaping_from_bomb = true
	

func _die():
	if is_alive():
		$HurtSound2.play()
		state = States.DEAD
		anim_tree.set("parameters/BlendRun/blend_position", 0)
		anim_tree.set("parameters/BlendRunCarry/blend_position", 0)
		controller.velocity = Vector3.ZERO
		emit_signal("on_died")
		_drop_gold()
		
		if is_instance_valid(bomb) and not bomb.is_dropped():
			bomb.hide()
			
		if has_weapon and is_instance_valid(weapon):
			_drop_weapon()
			weapon.hide()
			weapon.call_deferred("queue_free")

		controller.set_physics_process(false)
		$TargetDetectionTimer.stop()
		$BombIntervalTimer.stop()
		$BombDetectionTimer.stop()
		$BombEscapeTimer.stop()
		$OnWallTimer.stop()
		weapon_timer.stop()


func on_explosion_hit(_impulse = Vector3.ZERO):
	if is_alive():
		smoke_particles.emitting = true
		impulse = _impulse
		_die()
		
		yield(get_tree().create_timer(5), "timeout")
		smoke_particles.emitting = false


func on_weapon_hit(_impulse = Vector3.ZERO):
	time_to_die = 0
	impulse = _impulse
#	skeleton.physical_bones_add_collision_exception(get_rid())
#	skeleton.physical_bones_start_simulation()
#	body_bone.apply_central_impulse(impulse)
	_die()


func _drop_gold():
	if gold > 0:
		var angle = 0
		var offset = Vector3(0, 0, 0)
		while gold > 0:
			var item = GOLD_SCENE.instance()
			item.global_transform.origin = self.global_transform.origin + offset - Vector3.UP * 0.25
			get_parent().call_deferred("add_child", item)
#			print(name, " dropped gold! <<<<<<  ", item.name, " \n\n")
			gold -= 1
			offset += Vector3(0, 0.2, 0)
			if offset.y > 1.2:
				offset = Vector3(0, 0, 0)
				offset += 0.2 * Vector3.FORWARD.rotated(Vector3.UP, deg2rad(angle))
				angle += 30


func _drop_weapon():
	var item = _get_weapon_scene(weapon.TYPE).instance()
	get_node("../../Items").add_child(item)
	item.global_transform.origin = self.global_transform.origin
	item.global_transform.origin.y = 1.2


func _get_random_target_point():
	var aim_vector = (self.global_transform.basis.z + Vector3.UP * 2).rotated(Vector3.LEFT, deg2rad(15))
	var random_angle = rand_range(0, 360)
	var aim_range = 10
	var world_point = global_transform.rotated(Vector3.UP, deg2rad(random_angle)).translated(aim_vector * aim_range).origin
	var nav_point = controller.navigation.get_closest_point(world_point)
	return nav_point
	
	
func _get_random_destructible_target():
	if gold_piles.get_child_count() > 0:
		var arr = gold_piles.get_children()
		arr.shuffle()
		return arr[0]
	elif obstacles.get_child_count() > 0:
		var arr = obstacles.get_children()
		arr.shuffle()
		return arr[0]
	else:
		return null
		

func _get_player_position():
	if is_instance_valid(player):
		return player.global_transform.origin
	else:
		return null


func _get_run_away_point(from: Vector3):
	var found_point = false
	var tries = 20
	var angle = 0
	var min_distance = 7
	var nav_point
	
	while not found_point:
		var direction = (global_transform.origin - from).rotated(Vector3.UP, deg2rad(angle))
		direction.y = 0
		var offset = 10
		var world_point = global_transform.origin + direction.normalized() * offset
		nav_point = controller.navigation.get_closest_point(world_point)
#		print("Escaping from bomb...[", angle  ,"]  ... ", nav_point, " ... ", tries)
		yield(get_tree(), "idle_frame")
		
		if abs((nav_point - from).length()) >= min_distance or tries <= 0:
#			print("Found run away point")
			escape_point = nav_point
			emit_signal("found_escape_point")
			return nav_point
		else:
			angle += 180 / tries
			tries -= 1
			
	return nav_point
			


func _on_TargetDetectionTimer_timeout():
	if is_escaping_from_bomb or not is_alive():
		return
		
#	if name == "NPC5":
#		print("Target detection timeout: ", target_detection_area.get_overlapping_bodies())
	
	var found_item = false
	var found_miner = false
	var found_obstacle = null
	var found_obstacle_distance = INF
	var space = get_world().direct_space_state
	
	for body in target_detection_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id():
			if body.is_in_group("Items"):
				var hitpoint = body.hitpoint.global_transform.origin
				var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 0b10101)
				if not ray.empty() and ray.collider.get_instance_id() == body.get_instance_id():
					if ray.collider.is_in_group("Items"):
						found_item = true
						controller.target = body
						state = States.FOLLOWING
#						print("Item target found : ", body.name)
						random_following_timer.stop()
						return
						
			elif body.is_in_group("Player") and not found_item:
				var hitpoint = body.global_transform.origin if not "body_hitpoint" in body else body.body_hitpoint.global_transform.origin
				var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
				if not ray.empty() and ray.collider.get_instance_id() == body.get_instance_id():
					if ray.collider.is_in_group("Player") and ray.collider.is_alive():
						found_miner = true
						controller.target = body
						state = States.FOLLOWING
						random_following_timer.stop()
#						print("Player target found : ", body.name)
						return
						
			elif body.is_in_group("Obstacles") and not found_miner and not found_item:
				if state == States.EXPLORING and (not is_instance_valid(controller.target) or not controller.target.is_in_group("Obstacles")):
					for hit_pos in body.hitpoints.get_children():
						var hitpoint = hit_pos.global_transform.origin
						var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
	#					print(body.name, " - ", body, " - ", hit_pos.name, " - ", ray.collider)
						if not ray.empty() and ray.collider.get_instance_id() == body.get_instance_id():
							if ray.collider.is_in_group("Obstacles"):
								var distance = sight_origin.global_transform.origin.distance_to(hitpoint)
								if distance < found_obstacle_distance:
									found_obstacle_distance = distance
									found_obstacle = body
	#								if name == "NPC5":
#									print("Obstacle target found : ", body.name)
			
	if is_instance_valid(found_obstacle):
#		print("Obstacle chosen : ", found_obstacle.name)
		controller.target = found_obstacle
		state = States.FOLLOWING
		random_following_timer.stop()
	elif not found_miner and not found_item:
		if not is_instance_valid(controller.target): 
			var random_target = _get_random_destructible_target()
			if random_target:
#				print("\n Following random destructible  ", random_target)
				controller.target = random_target
				state = States.EXPLORING
				random_following_timer.stop()
			elif is_instance_valid(player) and player.is_alive():
				controller.target = player
				state = States.EXPLORING
				random_following_timer.stop()
			else:
				var random_point = _get_random_target_point()
				if random_following_timer.is_stopped():
					controller.move_to(random_point)
			#		print("random target", random_point)
					state = States.EXPLORING
					random_following_timer.start()
#					print("New target: RANDOM - ", random_point)


func _get_best_target_around():
	var found_miner = false
	var found_obstacle = null
	var found_obstacle_distance = INF
	var space = get_world().direct_space_state
	for body in target_detection_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id():
			if body.is_in_group("Player"):
				var hitpoint = body.global_transform.origin if not "body_hitpoint" in body else body.body_hitpoint.global_transform.origin
				var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
				if not ray.empty() and ray.collider.get_instance_id() == body.get_instance_id():
					if ray.collider.is_in_group("Player") and ray.collider.is_alive():
						found_miner = true
						# Return player if there's one in sight
						return body
						
			elif body.is_in_group("Obstacles") and not found_miner:
#				if state == States.EXPLORING and (not is_instance_valid(controller.target) or not controller.target.is_in_group("Obstacles")):
				for hit_pos in body.hitpoints.get_children():
					var hitpoint = hit_pos.global_transform.origin
					var ray = space.intersect_ray(sight_origin.global_transform.origin, hitpoint, [self], 1)
#					print(body.name, " - ", body, " - ", hit_pos.name, " - ", ray.collider)
					if not ray.empty() and ray.collider.get_instance_id() == body.get_instance_id():
						if ray.collider.is_in_group("Obstacles"):
							var distance = sight_origin.global_transform.origin.distance_to(hitpoint)
							if distance < found_obstacle_distance:
								found_obstacle_distance = distance
								found_obstacle = body
	
	# If no player was detected, return closes obstacle, or null if none was around
	if is_instance_valid(found_obstacle):
		return found_obstacle
	else:
		return null
		

func _on_BombIntervalTimer_timeout():
	if not is_alive():
		return
		
	if not _can_throw():
		for body in bomb_trigger_area.get_overlapping_bodies():
			if body.get_instance_id() != self.get_instance_id():
				if (body.is_in_group("Player") and body.is_alive()) or body.is_in_group("Obstacles"):
					# if gets close to target, drops a bomb
					if _can_drop_bomb():
						_drop_bomb()
					elif _can_attack():
						_attack()
	else:
		var target = _get_best_target_around()
		if is_instance_valid(target):
			_throw_weapon(target)
		


func _on_BombDetectionTimer_timeout():
	if not is_alive():
		return

	for body in bomb_trigger_area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue
		if body.get_instance_id() != self.get_instance_id() and body.is_in_group("Bombs") and body.is_dropped():
			if not is_escaping_from_bomb or body.global_transform.origin.distance_to(escape_point) > 3:
				# if notice a bomb, try to escape 
				_get_run_away_point(body.global_transform.origin)
				yield(self, "found_escape_point")
				controller.move_to(escape_point)
				if is_instance_valid(body) and not body.is_connected("bomb_exploded", self, "_on_BombEscapeTimer_timeout"):
					(body as Bomb).connect("bomb_exploded", self, "_on_BombEscapeTimer_timeout")
				$BombEscapeTimer.start()
	#			print("Escaping!!!!! ", escape_point)
				is_escaping_from_bomb = true


func _on_BombEscapeTimer_timeout():
#	print("No longer escaping")
	is_escaping_from_bomb = false
	$BombEscapeTimer.stop()


func _on_ForgetTargetTimer_timeout():
	if not is_alive():
		return

	if controller.target != null:
		if is_instance_valid(controller.target) and controller.target.is_in_group("Player") and not controller.target.is_alive():
			controller.target = null
			var random_point = _get_random_target_point()
			controller.move_to(random_point)
#			if name == "NPC6":
#			print("Forgot miner target ", random_point)
			state = States.EXPLORING
		elif is_instance_valid(controller.target) and controller.target.is_in_group("Obstacles") and controller.target.destroyed:
			controller.target = null
			var random_point = _get_random_target_point()
			controller.move_to(random_point)
			state = States.EXPLORING
#			print("Forgot obstacle target ", random_point)
			
		elif is_instance_valid(controller.target) and controller.target.is_in_group("Items"):
			return
		else:
			return
			controller.target = null
			var random_point = _get_random_target_point()
			controller.move_to(random_point)
#			print("Forgot last target ", random_point)
			state = States.EXPLORING

	# Repairs potential bug that prevents the dropped_bombs to reset
	if not has_bomb and not has_weapon and not is_instance_valid(bomb) and dropped_bombs > 0:
		dropped_bombs = 0
		_spawn_bomb()


func on_gold_collected():
	gold += 1
#	print(name, " collected ", str(gold), " kg of gold!")


func _on_OnWallTimer_timeout():
	if global_transform.origin.distance_to(wall_position) < 1 and is_alive():
		var random_point = _get_random_target_point()
		controller.move_to(random_point)
		
#		print("Timeout on WALL - ", random_point)
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
		
		"MINIAXE":
			return MINIAXE_SCENE


func on_weapon_collected(type: String, time_spent = 0):
	has_weapon = true
	weapon = _get_weapon_scene(type).instance()
	weapon.equip(self)
	weapon.TIME_SPENT = time_spent
	
	target_blend_carry = 0
	has_bomb = false
	if bomb_loc.get_child_count() > 0 and not bomb_loc.get_children()[0].is_dropped():
		bomb_loc.get_children()[0].hide()
		bomb_loc.get_children()[0].call_deferred("queue_free")

	if is_instance_valid(bomb) and not bomb.is_dropped():
		bomb.hide()
		bomb.call_deferred("queue_free")
		
	if weapon_loc.get_child_count() > 0:
		weapon_loc.get_children()[0].hide()
		weapon_loc.get_children()[0].call_deferred("queue_free")
		
	weapon_loc.call_deferred("add_child", weapon)
	
	bomb_interval_timer.wait_time = weapon.ATTACK_INTERVAL
	bomb_interval_timer.start()
	
	var time_left = weapon.DURATION - time_spent
	weapon_timer.paused = false
	weapon_timer.start(time_left)


func _attack():
	if has_weapon and is_instance_valid(weapon):
		weapon.start_attack(0.2, 0.4)
		anim_tree.set("parameters/Slash/active", true)


func _throw_weapon(target: Spatial):
	if has_weapon and is_instance_valid(weapon):
		var type = weapon.TYPE
		anim_tree.set("parameters/Slash/active", true)		
		yield(get_tree().create_timer(0.35), "timeout")
		var direction: Vector3 = target.global_transform.origin - weapon_loc.global_transform.origin
		direction = direction.rotated(Vector3.UP, rand_range(deg2rad(-10), deg2rad(10)))
		direction.y = 0
		hurt_sound.play() 
		if is_instance_valid(weapon):
			(weapon as ThrowableWeapon).throw(direction.normalized(), 70)
			weapon_timer.stop()
			weapon_timer.paused = false
			
#		yield(get_tree().create_timer(2), "timeout")
#		on_weapon_collected(type)
		

func _on_WeaponTimer_timeout(prevent_deletion = false):
	if is_instance_valid(weapon):
		if not prevent_deletion and weapon.DELETE_AFTER_TIMER:
			weapon.delete()
			weapon = null
		has_weapon = false
		if dropped_bombs < max_bombs and not has_bomb:
			_spawn_bomb()


func is_overlapping_body():
	if not is_instance_valid(inner_area):
		return false
	
	for body in inner_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id() and not body is PhysicalBone:
			print(body, " ", body.name)
			return true
	return false
	

func remove_inner_area():
	if not is_instance_valid(inner_area):
		return false
	inner_area.call_deferred("queue_free")
	
	
func set_dizzy(dizzy: bool):
	is_dizzy = dizzy
	anim_tree.set("parameters/DeadOrAlive/current", 0 if not dizzy else 2)
	

func _on_VisibilityNotifier_screen_exited():
	hide()


func _on_VisibilityNotifier_screen_entered():
	show()


