extends Spatial

export(NodePath) var PLAYER_PATH  = ""
export(NodePath) var BODY_PATH  = ""

export(float) var MOUSE_SENSITIVITY = 8
export(float) var MAX_ROTATION = 20
export(float) var MAX_ZOOM = 0.5
export(float) var MIN_ZOOM = 1.5
export(float) var ZOOM_SPEED = 2
export(float) var WALK_SPEED = 10
export(float) var RUN_SPEED = 20
export(float) var ANGULAR_ACCELERATION = 7
export(float) var ACCELERATION = 6
export(float) var GRAVITY = 5

var player: Spatial
var body: Spatial
var gimbalH: Spatial
var gimbalV: Spatial
var mouse_rotation = Vector2()
var zoom_factor = 1
var current_zoom = 1

var direction = Vector3.FORWARD
var h_rot
var gravity = -10
var movement_speed = 0
var velocity = Vector3.ZERO
var vertical_velocity = 0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player = get_node(PLAYER_PATH)
	body = get_node(BODY_PATH)
	gimbalH =  $h
	gimbalV =  $h/v
	pass

func _unhandled_input(event):
	
	if event is InputEventMouseMotion :
		mouse_rotation = event.relative
	
	if event is InputEventMouseButton:
		match event.button_index:
			BUTTON_WHEEL_UP:
				zoom_factor -= 0.05
			BUTTON_WHEEL_DOWN:
				zoom_factor += 0.05
		zoom_factor = clamp(zoom_factor, MAX_ZOOM, MIN_ZOOM)
		
	

func _physics_process(delta):
	# Horizontal Translation ----------------------
	if Input.is_action_pressed("move_forward") ||  Input.is_action_pressed("move_backward") ||  Input.is_action_pressed("move_left") ||  Input.is_action_pressed("move_right"):
		h_rot = gimbalH.global_transform.basis.get_euler().y
		direction = Vector3(
			Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
			0,
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward"))
		
#		strafe_dir = direction
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		
		if not Input.is_action_pressed("run"):
			movement_speed = RUN_SPEED
		else:
			movement_speed = WALK_SPEED
		
	else:
		movement_speed = 0
#		strafe_dir = Vector3.ZERO

	velocity = lerp(velocity, -direction * movement_speed, delta * ACCELERATION)
	
	# Body rotation
	var angle_dir_rot = atan2(-direction.x, -direction.z) - player.rotation.y
	body.rotation.y = lerp_angle(body.rotation.y, angle_dir_rot, delta * ANGULAR_ACCELERATION)
	
	# Camera rotation
	gimbalH.rotate_y(deg2rad(-mouse_rotation.x)*delta*MOUSE_SENSITIVITY)
	gimbalV.rotate_x(deg2rad(-mouse_rotation.y)*delta*MOUSE_SENSITIVITY)
	gimbalV.rotation_degrees.x = clamp(gimbalV.rotation_degrees.x, -MAX_ROTATION, MAX_ROTATION)
	mouse_rotation = Vector2()
	
	# Vertical velocity
	if not player.is_on_floor():
		vertical_velocity += GRAVITY * delta
	else:
		vertical_velocity = 0
	
	# Main movement
	velocity = player.move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP)
	
	#Zoom
	current_zoom = lerp(current_zoom, zoom_factor, delta * ZOOM_SPEED)
	gimbalH.set_scale(Vector3(current_zoom,current_zoom,current_zoom))
