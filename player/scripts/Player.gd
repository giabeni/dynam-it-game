extends KinematicBody

enum States {
	ALIVE,
	DEAD
}

onready var controller = $Controller
onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var bomb_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Bomb
onready var weapon_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Weapon
onready var smoke_particles: Particles = $SmokeParticles
onready var footsteps = $Footsteps
onready var body_hitpoint: Position3D = $CharacterArmature/BodyHitpoint
onready var hurt_sound: AudioStreamPlayer3D = $HurtSound
onready var breath_sound: AudioStreamPlayer3D = $BreathSound
onready var weapon_timer: Timer = $WeaponTimer

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")
export(PackedScene) var PICKAXE_SCENE = preload("res://weapons/scenes/Pickaxe.tscn")
export(NodePath) var UI_PATH

var bomb: Bomb
var weapon: Weapon
var has_bomb = false
var has_weapon = false
var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var state = States.ALIVE
var gold = 0
var bomb_range = 5
var max_bombs: int = 1
var dropped_bombs: int = 0
var player_ui: PlayerUI

signal on_died
signal on_gold_collected


func _ready():
	if max_bombs > 0:
		_spawn_bomb()
		
	player_ui = get_node(UI_PATH)
	

func _physics_process(delta):
	_set_animations(delta)
	

func _spawn_bomb():
	if has_weapon:
		return
	
	bomb = BOMB_SCENE.instance()
	bomb.set_range(bomb_range)
	bomb_loc.call_deferred("add_child", bomb)
	target_blend_carry = 1
	bomb.connect("bomb_exploded", self, "_on_bomb_exploded")
	has_bomb = true


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
	return has_bomb

	
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
		elif _can_drop_bomb():
			_drop_bomb()
		
	elif event.is_action_pressed("attack"):
		_attack()
		
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
	elif type == "BOMB_RANGE":
		bomb_range += amount
		if is_instance_valid(bomb):
			bomb.set_range(bomb_range)
			player_ui.show_power_up_text("Dynamites range increased to " + str(bomb_range))
	elif type == "EXTRA_BOMB":
		max_bombs += 1
		player_ui.show_power_up_text("Max active dynamites incresead to " + str(max_bombs))


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
	if has_weapon and is_instance_valid(weapon):
		weapon.start_attack(1.042, 0.27)
		anim_tree.set("parameters/Slash/active", true)


func _on_WeaponTimer_timeout():
	if is_instance_valid(weapon):
		weapon.call_deferred("queue_free")
		has_weapon = false
		player_ui.set_current_powerup_timer(0)
		if dropped_bombs < max_bombs and not has_bomb:
			_spawn_bomb()
