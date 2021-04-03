extends KinematicBody

enum States {
	ALIVE,
	DEAD
}

onready var controller = $Controller
onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var bomb: Bomb
onready var bomb_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Bomb
onready var smoke_particles: Particles = $SmokeParticles
onready var footsteps = $Footsteps
onready var body_hitpoint: Position3D = $CharacterArmature/BodyHitpoint

export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")

var has_bomb = false
var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var available_bombs: int = 1
var state = States.ALIVE

func _ready():
	if available_bombs > 0:
		_spawn_bomb()
		
#	smoke_particles.hide()
#	smoke_particles.emitting = true
#	yield(get_tree().create_timer(0.5), "timeout")
#	smoke_particles.emitting = false
#	smoke_particles.show()
	

func _physics_process(delta):
	_set_animations(delta)
	

func _spawn_bomb():
	bomb = BOMB_SCENE.instance()
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
		
	elif state == States.DEAD:
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

	
func _input(event):
	if event.is_action("drop_bomb") and _can_drop_bomb():
		_drop_bomb()
		
	elif event.is_action("reset"):
		get_tree().reload_current_scene()
		
func is_alive():
	return state in [States.ALIVE]
		

func _drop_bomb():
	bomb.drop()
	should_drop_bomb = true
	available_bombs -= 1
	

func on_explosion_hit():
	smoke_particles.emitting = true
	state = States.DEAD
	controller.set_physics_process(false)
