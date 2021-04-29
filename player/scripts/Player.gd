extends KinematicBody

enum States {
	ALIVE,
	DEAD
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
onready var weapon_timer: Timer = $WeaponTimer
onready var grab_area: Area = $CharacterArmature/Skeleton/Body/CarryArea
onready var aim_circle: CSGTorus = $Controller/h/v/Camera/AimCircle

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")
export(PackedScene) var PICKAXE_SCENE = preload("res://weapons/scenes/Pickaxe.tscn")
export(NodePath) var UI_PATH
export(float) var THROW_FORCE = 700

var bomb: Bomb
var weapon: Weapon
var has_bomb = false
var has_weapon = false
var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var state = States.ALIVE
var gold = 0
var bomb_range = 2.5
var max_bombs: int = 1
var dropped_bombs: int = 0
var player_ui: PlayerUI
var grabbed_object: RigidBody = null
var throw_force_amount = 0
var aiming = false


signal on_died
signal on_gold_collected


func _ready():
	player_ui = get_node(UI_PATH)
	
	controller.set_camera_position("DEFAULT")	
	set_physics_process(false)
	set_process(false)
	set_process_internal(false)
	set_physics_process_internal(false)
	controller.set_physics_process(false)
	
	yield(get_tree(), "physics_frame")
	player_ui.set_dynamites(max_bombs)
	player_ui.set_speed(controller.RUN_SPEED)
	player_ui.set_range(bomb_range)
	

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
			(aim_circle.material as SpatialMaterial).albedo_color = Color("#0072ff").linear_interpolate(Color("#dd1a12"), throw_force_amount)
			var aim_size = 1 + throw_force_amount
			aim_circle.inner_radius = aim_circle.outer_radius - aim_circle.outer_radius * throw_force_amount
		elif has_weapon:
			if Input.is_action_pressed("attack"):
				aim_circle.show()
				aiming = true
				aim_circle.inner_radius = aim_circle.outer_radius * 0.8
				
		else:
			aim_circle.hide()
	

func _spawn_bomb():
	
	if has_weapon or has_bomb:
		return
	
	has_bomb = true
	bomb = BOMB_SCENE.instance()
	bomb.set_range(bomb_range)
	bomb_loc.add_child(bomb)
	target_blend_carry = 1
	bomb.connect("bomb_exploded", self, "_on_bomb_exploded")


func _grab_objects():
	if not is_instance_valid(grabbed_object):
		if Input.is_action_just_pressed("grab"):
			for body in grab_area.get_overlapping_bodies():
				if body.is_in_group("Grabbables"):
					body.set_grabbed_by(carry_loc, self)
					grabbed_object = body
					if is_instance_valid(bomb):
						bomb.hide()
					return
	else:
		if Input.is_action_just_pressed("grab"):
			grabbed_object.set_grabbed_by(null, null)
			grabbed_object = null
			throw_force_amount = 0
			if is_instance_valid(bomb):
				bomb.show()
			

func _throw_object():
	if Input.is_action_pressed("attack"):
		aim_circle.show()
		aiming = true
		controller.set_camera_position("AIM")
		throw_force_amount += 0.01
		throw_force_amount = clamp(throw_force_amount, 0.1, 1)
	elif Input.is_action_just_released("attack"):
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
		
		# Power up timer update
		if has_weapon:
			player_ui.set_current_powerup_timer(weapon_timer.time_left)
		
	elif state == States.DEAD:
		anim_tree.set("parameters/DeadOrAlive/current", 1)


func _can_drop_bomb():
	return has_bomb and not is_instance_valid(grabbed_object)

	
func _on_bomb_dropped():
	has_bomb = false
	if dropped_bombs < max_bombs and not has_bomb:
		_spawn_bomb()


func _on_bomb_exploded():
	dropped_bombs -= 1
	if dropped_bombs < max_bombs and not has_bomb:
		_spawn_bomb()

	
func _input(event: InputEvent):
	if event.is_action_released("drop_bomb"):
		if has_weapon:
			_attack()
			aiming = false
			
		elif _can_drop_bomb():
			_drop_bomb()
		
	elif event.is_action_released("attack"):
		_attack()
		aiming = false
		
		
	elif event.is_action("reset"):
		get_tree().reload_current_scene()
	
		
func is_alive():
	return state in [States.ALIVE]
		

func _drop_bomb():
	
	bomb.is_from_player = true
	dropped_bombs += 1
	bomb.drop()
	should_drop_bomb = true
	


func on_explosion_hit():
	breath_sound.stop()
	smoke_particles.emitting = true
	state = States.DEAD
	emit_signal("on_died")
	controller.set_physics_process(false)


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
	player_ui.set_powerup_timer(weapon.ICON_PATH, weapon.DURATION)
		
		
func on_weapon_hit():
	breath_sound.stop()
	$HurtSound2.play()
	state = States.DEAD
	emit_signal("on_died")
	controller.set_physics_process(false)
	

func _attack():
	if has_weapon and is_instance_valid(weapon) and weapon.damage_free_timer.is_stopped():
		weapon.start_attack(1.042, 0.27)
		anim_tree.set("parameters/Slash/active", true)


func _on_WeaponTimer_timeout():
	if is_instance_valid(weapon):
		weapon.call_deferred("queue_free")
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
