extends KinematicBody

enum States {
	ALIVE,
	DEAD
}

onready var body = $CharacterArmature
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
onready var foot_left: BoneAttachment = $CharacterArmature/Skeleton/FootLeft
onready var foot_right: BoneAttachment = $CharacterArmature/Skeleton/FootRight

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")
export(PackedScene) var PICKAXE_SCENE = preload("res://weapons/scenes/Pickaxe.tscn")
export(PackedScene) var FOOTPRINT_SCENE = preload("res://player/scenes/Footprint.tscn")
export(NodePath) var UI_PATH
export(NodePath) var FOOTPRINTS_PATH = '../Map/Navigation/Footprints'
export(float) var THROW_FORCE = 700
export(float) var RUN_SPEED = 14
export(bool) var IS_MULTIPLAYER = false

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
var impulse = Vector3.ZERO
var aiming = false
var footprints: Spatial

var next_origin: Vector3 = Vector3.ZERO
var next_rotation: Vector3 = Vector3.ZERO
var velocity = Vector3.ZERO
var vel_factor = 0
var next_vel_factor = 0


func _physics_process(delta):
	
	# Move interpolated to next origin
	if next_origin.distance_to(global_transform.origin) > 0.001:
		var new_velocity = (next_origin - global_transform.origin) / delta
		velocity = velocity.linear_interpolate(new_velocity, delta * 3)
		
#		vel_factor = lerp(vel_factor, next_vel_factor, 1)
		global_transform.origin = lerp(global_transform.origin, next_origin, 1) # Interpolate

	# Rotate interpolated to next origin
	if next_rotation.distance_to(rotation) > 0.0001:
		body.rotation.x = lerp_angle(rotation.x, next_rotation.x, 1) # Interpolate
		body.rotation.y = lerp_angle(rotation.y, next_rotation.y, 1) # Interpolate
		body.rotation.z = lerp_angle(rotation.z, next_rotation.z, 1) # Interpolate
		
	_set_animations(delta)


func _set_animations(delta):
	
	if state == States.ALIVE:
		anim_tree.set("parameters/DeadOrAlive/current", 0)
		
		var h_velocity: Vector2 = Vector2(velocity.x, velocity.z)
		vel_factor = h_velocity.length() / RUN_SPEED
		anim_tree.set("parameters/BlendRun/blend_position", vel_factor)
		anim_tree.set("parameters/BlendRunCarry/blend_position", vel_factor)
		
		if should_drop_bomb:
			target_blend_carry = 0
			if blend_carry <= 0.1:
				should_drop_bomb = false
				footsteps.enabled = false
#				_on_bomb_dropped()
				
		footsteps.enabled = vel_factor > 0.05
		
		blend_carry = lerp(blend_carry, target_blend_carry, delta * 6)
		anim_tree.set("parameters/BlendCarry/blend_amount", blend_carry)
		
		# Power up timer update
		if has_weapon:
			player_ui.set_current_powerup_timer(weapon_timer.time_left)
		
	elif state == States.DEAD:
		anim_tree.set("parameters/DeadOrAlive/current", 1)



func _add_footprint(is_right):
	pass


func move_player(new_origin, _vel_factor = null, new_rotation = null):
	next_origin = new_origin
	if new_rotation != null:
		next_rotation = new_rotation
	if vel_factor != 0:
		next_vel_factor = _vel_factor
#	global_transform.origin = next_origin
#	rotation = next_rotation
