extends Spatial

export(NodePath) var NPC_PATH  = ""
export(NodePath) var BODY_PATH  = ""
export(NodePath) var TARGET_PATH  = "../../../../"
export(NodePath) var NAV_PATH  = null

export(float) var MOUSE_SENSITIVITY = 8
export(float) var MAX_ROTATION = 20
export(float) var MAX_ZOOM = 0.5
export(float) var MIN_ZOOM = 1.5
export(float) var ZOOM_SPEED = 2
export(float) var WALK_SPEED = 7
export(float) var RUN_SPEED = 14
export(float) var ANGULAR_ACCELERATION = 7
export(float) var ACCELERATION = 4
export(float) var GRAVITY = 5
export(float) var INERTIA = 3
export(float) var NEW_TARGET_DETECTED_INTERVAL = 0.5

var navigation: NavGrid
var npc: Spatial
var body: Spatial
var target: Spatial

var direction = Vector3.FORWARD
var h_rot
var gravity = -10
var movement_speed = 0
var velocity = Vector3.ZERO
var vertical_velocity = 0

var path = []
var path_node = 0


func _ready():
	npc = get_node(NPC_PATH)
	body = get_node(BODY_PATH)
#	target = get_tree().current_scene.get_node("Player")
	if NAV_PATH:
		navigation = get_node(NAV_PATH)
		
	$DetectTargetTimer.wait_time = NEW_TARGET_DETECTED_INTERVAL
	

func _physics_process(delta):
	
	# Follow path
	if path_node < path.size():
		var distance_to_path: Vector3 = path[path_node] - npc.global_transform.origin
		var dist = Vector2(distance_to_path.x, distance_to_path.z).length()
		if abs(dist) < 0.75:
			path_node += 1
			movement_speed = 0
		else:
			movement_speed = RUN_SPEED
			direction = distance_to_path.normalized()
	
	
	# Main movement
	if npc.is_alive() and not npc.is_dizzy:	
		apply_movement(delta)
		

func apply_movement(delta):
		velocity = lerp(velocity, direction * movement_speed, delta * ACCELERATION)
		
		# Body rotation
		var angle_dir_rot = atan2(direction.x, direction.z) - npc.rotation.y
		body.rotation.y = lerp_angle(body.rotation.y, angle_dir_rot, delta * ANGULAR_ACCELERATION)
		
		# Vertical velocity
		if not npc.is_on_floor():
			vertical_velocity += GRAVITY * delta
		else:
			vertical_velocity = 0
	
		velocity = npc.move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP, false, 4, PI/4, false)



func move_to(target_pos, custom_path = null):
	if not custom_path:
		path = navigation.get_simple_path(npc.global_transform.origin, target_pos, true)
		path_node = 0
		
	else:
		path = custom_path
		path_node = 0


func _on_DetectTargetTimer_timeout():
#	if get_parent().name == "NPC6":
#		print("path update timeout")
	if not npc.is_escaping_from_bomb and is_instance_valid(target):
		move_to(target.global_transform.origin)
		
