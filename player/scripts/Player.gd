extends KinematicBody


onready var controller = $Controller
onready var anim_tree: AnimationTree = $AnimationTree
onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var bomb: Bomb
onready var bomb_loc: Spatial = $CharacterArmature/Skeleton/HandRight/Bomb


export(PackedScene) var BOMB_SCENE = preload("res://bombs/TNTPile.tscn")

var should_drop_bomb = false
var blend_carry: float = 0
var target_blend_carry: float = 0
var available_bombs: int = 1

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


func _set_animations(delta):
	var h_velocity: Vector2 = Vector2(controller.velocity.x, controller.velocity.z)
	var vel_factor = h_velocity.length() / controller.RUN_SPEED
	anim_tree.set("parameters/BlendRun/blend_position", vel_factor)
	anim_tree.set("parameters/BlendRunCarry/blend_position", vel_factor)
	
	if should_drop_bomb:
		target_blend_carry = 0
		if blend_carry <= 0.1:
			should_drop_bomb = false
			_on_bomb_dropped()
	
	blend_carry = lerp(blend_carry, target_blend_carry, delta * 6)
	anim_tree.set("parameters/BlendCarry/blend_amount", blend_carry)
		

func _can_drop_bomb():
	return true

	
func _on_bomb_dropped():
	print("dropped: ", available_bombs)
	if available_bombs > 0:
		_spawn_bomb()


func _on_bomb_exploded():
	available_bombs += 1
	print("exploded: ", available_bombs)
	_spawn_bomb()

	
func _input(event):
	if event.is_action("drop_bomb") and _can_drop_bomb():
		_drop_bomb()
		
		
func _drop_bomb():
	bomb.drop()
	should_drop_bomb = true
	available_bombs -= 1
