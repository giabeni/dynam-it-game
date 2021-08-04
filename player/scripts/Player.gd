extends KinematicBody

enum States {
	ALIVE,
	DEAD
}

enum {
	WASD,
	CONTROLLER_1,
	CONTROLLER_2
}

onready var controller = $Controller
onready var camera: Camera = $Controller/h/v/Camera
onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var bomb_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Bomb
onready var weapon_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Weapon
onready var carry_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Carry
onready var smoke_particles: Particles = $SmokeParticles
onready var footsteps = $Footsteps
onready var body_hitpoint: Position3D = $CharacterArmature/BodyHitpoint
onready var hurt_sound: AudioStreamPlayer3D = $HurtSound
onready var breath_sound: AudioStreamPlayer3D = $BreathSound
onready var ear_ring_sound: AudioStreamPlayer = $EarRingSound
onready var weapon_timer: Timer = $WeaponTimer
onready var grab_area: Area = $CharacterArmature/Skeleton/Body/CarryArea
onready var aim_circle: CSGTorus = $Controller/h/v/Camera/AimCircle
onready var foot_left: BoneAttachment = $CharacterArmature/Skeleton/FootLeft
onready var foot_right: BoneAttachment = $CharacterArmature/Skeleton/FootRight

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")
export(PackedScene) var PICKAXE_SCENE = preload("res://weapons/scenes/Pickaxe.tscn")
export(PackedScene) var MINIAXE_SCENE = preload("res://weapons/scenes/MiniAxe.tscn")
export(PackedScene) var FOOTPRINT_SCENE = preload("res://player/scenes/Footprint.tscn")
export(NodePath) var UI_PATH
export(NodePath) var FOOTPRINTS_PATH = '../Map/Navigation/Footprints'
export(float) var THROW_FORCE = 700
export(float) var MIN_IMPACT_TO_BE_DIZZY = 2000
export(bool) var IS_MULTIPLAYER = false
export(bool) var START_DISABLED = true
export(int) var INPUT_SRC = WASD

var bomb: Bomb
var weapon: Weapon
var has_bomb = false
var has_weapon = false
var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var vel_factor = 0
var state = States.ALIVE
var gold = 0
var bomb_range = 2.5
var max_bombs: int = 1
var dropped_bombs: int = 0
var player_ui: PlayerUI
var is_dizzy = false
var grabbed_object: RigidBody = null
var throw_force_amount = 0
var impulse = Vector3.ZERO
var aiming = false
var footprints: Spatial
var player_state = {}


signal on_died
signal on_gold_collected


func _ready():
	player_ui = get_node(UI_PATH)
	footprints = get_node(FOOTPRINTS_PATH)
	
	controller.set_camera_position("DEFAULT")	
	if START_DISABLED:
		set_physics_process(false)
		set_process(false)
		set_process_internal(false)
		set_physics_process_internal(false)
		controller.set_physics_process(false)
	
	yield(get_tree(), "physics_frame")
	player_ui.set_dynamites(max_bombs)
	player_ui.set_speed(controller.RUN_SPEED)
	player_ui.set_range(bomb_range)
	
	if not START_DISABLED:
		_spawn_bomb()

func enable():
	set_physics_process(true)
	set_process(true)
	set_process_internal(true)
	set_physics_process_internal(true)
	controller.set_physics_process(true)
	_spawn_bomb()


func _physics_process(delta):
	_set_animations(delta)
	
	# Repairs potential bug that prevents the dropped_bombs to reset
	if not has_bomb and not has_weapon and not is_instance_valid(bomb) and dropped_bombs > 0:
		dropped_bombs = 0
		_spawn_bomb()
		
	if is_alive():
		_grab_objects()
		if grabbed_object:
			_throw_object()
			(aim_circle.material as SpatialMaterial).albedo_color = Color("#ffffff").linear_interpolate(Color("#dd1a12"), throw_force_amount)
			var aim_size = 1 + throw_force_amount
			aim_circle.inner_radius = aim_circle.outer_radius - aim_circle.outer_radius * throw_force_amount
		elif has_weapon:
			if Input.is_action_pressed("attack_" + str(INPUT_SRC)):
				aim_circle.show()
				aiming = true
				controller.set_camera_position("AIM_WEAPON")
				aim_circle.inner_radius = aim_circle.outer_radius * 0.8
			else:
				aim_circle.hide()
				controller.set_camera_position("DEFAULT")
		else:
			aim_circle.hide()
			controller.set_camera_position("DEFAULT")
	else:
		var vel = Vector3.DOWN * controller.GRAVITY + impulse * delta
		if impulse != Vector3.ZERO:
			impulse = lerp(impulse, Vector3.ZERO, delta * controller.ACCELERATION)
#		print("Vel = ", vel)
		move_and_slide(vel, Vector3.UP)
	
	if IS_MULTIPLAYER:
		update_player_state()


func update_player_state():
	player_state = {
		"T": Server.client_clock,
		"O": global_transform.origin,
		"R": controller.body.rotation,
		"V": vel_factor,
	}
	Server.rooms.current_room.send_player_state(player_state)
	

func _spawn_bomb():
	
	if has_weapon or has_bomb:
		return
	
	has_bomb = true
	bomb = BOMB_SCENE.instance()
	bomb.set_range(bomb_range)
	bomb_loc.call_deferred("add_child", bomb)
	target_blend_carry = 1
	bomb.connect("bomb_exploded", self, "_on_bomb_exploded")


func _can_drop_bomb():
	return has_bomb and not is_instance_valid(grabbed_object) and not is_dizzy

	
func _on_bomb_dropped():
	has_bomb = false
	if dropped_bombs < max_bombs and not has_bomb:
		_spawn_bomb()


func _on_bomb_exploded():
	dropped_bombs -= 1
	if dropped_bombs < max_bombs and not has_bomb:
		_spawn_bomb()


func on_general_bomb_exploded(origin: Vector3):
	var distance = origin.distance_to(global_transform.origin)
	if distance < 50:
		var vibration = (50 - distance)/50 
		var duration = (50 - distance)/50 * 1.5
		Input.start_joy_vibration(0, vibration * 0.8, vibration * 0.6, duration)



func _grab_objects():
	if not is_instance_valid(grabbed_object):
		if Input.is_action_just_pressed("grab_" + str(INPUT_SRC)):
			for body in grab_area.get_overlapping_bodies():
				if body.is_in_group("Grabbables"):
					body.set_grabbed_by(carry_loc, self)
					grabbed_object = body
					if is_instance_valid(bomb) and not bomb.is_dropped():
						bomb.hide()
					return
	else:
		if Input.is_action_just_pressed("grab_" + str(INPUT_SRC)):
			grabbed_object.set_grabbed_by(null, null)
			grabbed_object = null
			throw_force_amount = 0
			if is_instance_valid(bomb):
				bomb.show()
			

func _throw_object():
	if Input.is_action_pressed("attack_" + str(INPUT_SRC)):
		aim_circle.show()
		aiming = true
		controller.set_camera_position("AIM")
		throw_force_amount += 0.02
		throw_force_amount = clamp(throw_force_amount, 0.1, 1)
	elif Input.is_action_just_released("attack_" + str(INPUT_SRC)) and is_instance_valid(grabbed_object):
		grabbed_object.set_grabbed_by(null, self)
		controller.set_camera_position("DEFAULT")
		var direction = -camera.global_transform.basis.z
		hurt_sound.play()
		anim_tree.set("parameters/Punch/active", true)		
		grabbed_object.throw(direction.normalized() * THROW_FORCE * throw_force_amount)
		grabbed_object = null
		throw_force_amount = 0
		aiming = false
		aim_circle.hide()
		if is_instance_valid(bomb):
			bomb.show()

func _set_animations(delta):
	
	if state == States.ALIVE:
		anim_tree.set("parameters/DeadOrAlive/current", 0 if not is_dizzy else 2)
		
		var h_velocity: Vector2 = Vector2(controller.velocity.x, controller.velocity.z)
		vel_factor = h_velocity.length() / controller.RUN_SPEED
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
		
		# Power up timer update
		if has_weapon:
			player_ui.set_current_powerup_timer(weapon_timer.time_left)
		
	elif state == States.DEAD:
		anim_tree.set("parameters/DeadOrAlive/current", 1)


func on_obstacle_destroyed(origin: Vector3):
	var distance = origin.distance_to(global_transform.origin)
	if distance < 50:
		var vibration = (50 - distance)/50 
		var duration = (50 - distance)/50 * 0.5
		Input.start_joy_vibration(0, vibration * 0.7, vibration * 0.5 , duration)
	

func _input(event: InputEvent):
	if event.is_action_released("drop_bomb_" + str(INPUT_SRC)):
		if has_weapon and not is_dizzy:
			_attack()
			aiming = false
			
		elif _can_drop_bomb():
			_drop_bomb()
		
	elif event.is_action_released("attack_" + str(INPUT_SRC)):
		_attack()
		aiming = false
		
		
	elif event.is_action("reset"):
		get_tree().reload_current_scene()
		
	
	elif event.is_action_pressed("switch_control"):
		INPUT_SRC += 1
		if INPUT_SRC == 2:
			INPUT_SRC = 0
	
		
func is_alive():
	return state in [States.ALIVE]
		

func _drop_bomb():
	
	bomb.is_from_player = true
	dropped_bombs += 1
	bomb.drop()
	should_drop_bomb = true
	


func on_explosion_hit(_impulse = Vector3.ZERO):
	Input.start_joy_vibration(0, 0.8, 0.8, 2)	
	breath_sound.stop()
	smoke_particles.emitting = true
	ear_ring_sound.play()
	impulse = _impulse
	state = States.DEAD
	anim_tree.set("parameters/BlendRun/blend_position", 0)
	anim_tree.set("parameters/BlendRunCarry/blend_position", 0)
	controller.velocity = Vector3.ZERO
	emit_signal("on_died")
	controller.set_physics_process(false)

	yield(get_tree().create_timer(5), "timeout")
	smoke_particles.emitting = false


func on_gold_collected():
	gold += 1
	player_ui.set_gold(gold)
	emit_signal("on_gold_collected")


func on_powerup_collected(type, amount):
	if type == "VELOCITY":
		controller.RUN_SPEED += amount
		player_ui.show_power_up_text("Velocity increased to " + str(controller.RUN_SPEED))
		player_ui.set_speed(controller.RUN_SPEED)
	elif type == "BOMB_RANGE":
		bomb_range += amount
		player_ui.show_power_up_text("Dynamites range increased to " + str(bomb_range))
		player_ui.set_range(bomb_range)
		if is_instance_valid(bomb):
			bomb.set_range(bomb_range)
	elif type == "EXTRA_BOMB":
		max_bombs += 1
		player_ui.show_power_up_text("Max active dynamites incresead to " + str(max_bombs))
		player_ui.set_dynamites(max_bombs)


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
		weapon_loc.get_child(0).hide()
		weapon_loc.get_child(0).queue_free()
		
	weapon_loc.call_deferred("add_child", weapon)
	var time_left = weapon.DURATION - time_spent
	weapon_timer.paused = false
	weapon_timer.start(time_left)
	player_ui.set_current_powerup_timer(time_left)
	player_ui.set_powerup_timer(weapon.ICON_PATH, weapon.DURATION)
		
		
func on_weapon_hit(_impulse = Vector3.ZERO):
	breath_sound.stop()
	$HurtSound2.play()
	impulse = _impulse
	state = States.DEAD
	emit_signal("on_died")
	if is_instance_valid(bomb) and not bomb.is_dropped():
		bomb.hide()
	anim_tree.set("parameters/BlendRun/blend_position", 0)
	anim_tree.set("parameters/BlendRunCarry/blend_position", 0)
	controller.velocity = Vector3.ZERO
	controller.set_physics_process(false)
	

func _attack():
	if not has_weapon or not is_instance_valid(weapon) or is_dizzy:
		return
	
	if anim_tree.get("parameters/Slash/active") or not weapon.damage_free_timer.is_stopped():
		return
		
	if weapon.THROWABLE:
		anim_tree.set("parameters/Slash/active", true)		
		yield(get_tree().create_timer(0.35), "timeout")
		var direction = -camera.global_transform.basis.z
		direction.y = 0
		hurt_sound.play() 
		if is_instance_valid(weapon):
			(weapon as ThrowableWeapon).throw(direction.normalized(), 70)
			player_ui.set_current_powerup_timer(0)
			weapon_timer.paused = true
	else:
		weapon.start_attack(0.2, 0.4)
		anim_tree.set("parameters/Slash/active", true)


func _on_WeaponTimer_timeout(prevent_deletion = false):
	if is_instance_valid(weapon):
		if not prevent_deletion and weapon.DELETE_AFTER_TIMER:
			weapon.delete()
		has_weapon = false
		player_ui.set_current_powerup_timer(0)
		if dropped_bombs < max_bombs and not has_bomb:
			_spawn_bomb()


func _on_CarryArea_body_entered(body):
	if body.is_in_group("Grabbables") and "outline" in body:
		body.outline.show()


func _on_CarryArea_body_exited(body):
	if body.is_in_group("Grabbables") and "outline" in body:
		body.outline.hide()
		

func _add_footprint(is_right_foot: bool):
	if not footprints:
		return
	if controller.velocity.length() > 0.1:
		var foot = foot_right if is_right_foot else foot_left
		var footprint = FOOTPRINT_SCENE.instance()
		footprints.add_child(footprint)
		footprint.global_transform.origin = foot.global_transform.origin
		footprint.global_transform.origin.y = 0.7
		footprint.scale = Vector3.ONE * rand_range(0.8, 1.2)

	
func set_dizzy(dizzy: bool):
	is_dizzy = dizzy
	anim_tree.set("parameters/DeadOrAlive/current", 0 if not dizzy else 2)
	
