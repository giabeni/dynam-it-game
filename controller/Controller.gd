extends Spatial

export(NodePath) var PLAYER_PATH  = ""
export(NodePath) var BODY_PATH  = ""

export(float) var MOUSE_SENSITIVITY = 8
export(float) var MAX_ROTATION = 10
export(float) var MAX_ZOOM = 0.5
export(float) var MIN_ZOOM = 1.5
export(float) var ZOOM_SPEED = 2
export(float) var WALK_SPEED = 7
export(float) var RUN_SPEED = 14
export(float) var ANGULAR_ACCELERATION = 7
export(float) var ACCELERATION = 4
export(float) var GRAVITY = 5
export(float) var INERTIA = 5

var player: KinematicBody
var body: Spatial
var gimbalH: Spatial
var gimbalV: Spatial
var mouse_rotation = Vector2()
var new_mouse_rotation = Vector2()
var zoom_factor = 1
var current_zoom = 1

var direction = Vector3.FORWARD
var h_rot = 0
var gravity = -10
var movement_speed = 0
var velocity = Vector3.ZERO
var vertical_velocity = 0

onready var camera_position: Position3D = $h/v/DefaultCameraPosition
onready var default_camera_position: Position3D = $h/v/DefaultCameraPosition
onready var aim_camera_postion: Position3D = $h/v/AimCameraPosition
onready var aim_weapon_camera_postion: Position3D = $h/v/WeaponCameraPosition
onready var camera: Camera = $h/v/Camera

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player = get_node(PLAYER_PATH)
	body = get_node(BODY_PATH)
	gimbalH =  $h
	gimbalV =  $h/v
	pass
	

func _input(event):
	
	if not player.INPUT_SRC == player.CONTROLLER_1:
		if event is InputEventMouseMotion :
			mouse_rotation = event.relative * 1000 / OS.window_size
			
	else:
		new_mouse_rotation = Vector2(
			Input.get_action_strength("look_right") - Input.get_action_strength("look_left"),
			Input.get_action_strength("look_down") - Input.get_action_strength("look_up"))
			
		
	
#	if event is InputEventMouseButton:
#		match event.button_index:
#			BUTTON_WHEEL_UP:
#				zoom_factor -= 0.05
#			BUTTON_WHEEL_DOWN:
#				zoom_factor += 0.05
#		zoom_factor = clamp(zoom_factor, MAX_ZOOM, MIN_ZOOM)

	

func _physics_process(delta):
	
	# Horizontal Translation ----------------------
	if player.INPUT_SRC == player.WASD and (Input.is_action_pressed("move_forward") ||  Input.is_action_pressed("move_backward") ||  Input.is_action_pressed("move_left") ||  Input.is_action_pressed("move_right")):
		h_rot = gimbalH.global_transform.basis.get_euler().y
		direction = Vector3(
			Input.get_action_strength("move_left") - Input.get_action_strength("move_right"),
			0,
			Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward"))
		
#		strafe_dir = direction
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		
#		if not Input.is_action_pressed("run"):
		movement_speed = RUN_SPEED
#		else:
#			movement_speed = WALK_SPEED
		
	elif player.INPUT_SRC == player.CONTROLLER_1 and (Input.is_action_pressed("move_forward_joystick") ||  Input.is_action_pressed("move_backward_joystick") ||  Input.is_action_pressed("move_left_joystick") ||  Input.is_action_pressed("move_right_joystick")):
		h_rot = gimbalH.global_transform.basis.get_euler().y
		direction = Vector3(
			Input.get_action_strength("move_left_joystick") - Input.get_action_strength("move_right_joystick"),
			0,
			Input.get_action_strength("move_forward_joystick") - Input.get_action_strength("move_backward_joystick"))
		
#		strafe_dir = direction
		direction = direction.rotated(Vector3.UP, h_rot).normalized()
		
#		if not Input.is_action_pressed("run"):
		movement_speed = RUN_SPEED
	
	else:
		movement_speed = 0
#		strafe_dir = Vector3.ZERO

	velocity = lerp(velocity, -direction * movement_speed, delta * ACCELERATION)
	
	# Body rotation
	if not player.aiming:
		var angle_dir_rot = atan2(-direction.x, -direction.z) - player.rotation.y
		body.rotation.y = lerp_angle(body.rotation.y, angle_dir_rot, delta * ANGULAR_ACCELERATION)
	else:
		var aim_direction = -camera.global_transform.basis.z
		direction = -aim_direction
		var angle_dir_rot = atan2(aim_direction.x, aim_direction.z) - player.rotation.y
		body.rotation.y = lerp_angle(body.rotation.y, angle_dir_rot, delta * ANGULAR_ACCELERATION * 2)
	
	# Camera rotation
	if player.INPUT_SRC == player.CONTROLLER_1:
		mouse_rotation = lerp(mouse_rotation, new_mouse_rotation * 20, delta * 6)
		
	var sensitivity = Settings.JOYSTICK.CAMERA_SENSITIVITY if player.INPUT_SRC == player.CONTROLLER_1 else Settings.MOUSE.CAMERA_SENSITIVITY
	gimbalH.rotate_y(deg2rad(-mouse_rotation.x) * delta * sensitivity.x)
	gimbalV.rotate_x(deg2rad(-mouse_rotation.y) * delta * sensitivity.y)
	var max_vertical_rotation = MAX_ROTATION if player.aiming else 0
	gimbalV.rotation_degrees.x = clamp(gimbalV.rotation_degrees.x, -max_vertical_rotation, max_vertical_rotation)
	if not player.INPUT_SRC == player.CONTROLLER_1:
		mouse_rotation = Vector2()
	
	# Vertical velocity
	if not player.is_on_floor():
		vertical_velocity += GRAVITY * delta
	else:
		vertical_velocity = 0
	
	# Main movement
	if not get_parent().is_dizzy:
		velocity = player.move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP, false, 4, PI/4, is_instance_valid(player.grabbed_object))
	
	# Interact with rigid bodies
#	for col in player.get_slide_count():
#		var collision = player.get_slide_collision(col)
#		if collision == null:
#			return
#		if is_instance_valid(collision.collider) and collision.collider.is_in_group("Pushables") and (not is_instance_valid(player.grabbed_object) or collision.collider_id != player.grabbed_object.get_instance_id()):
#			(collision.collider as RigidBody).apply_central_impulse(-collision.normal * INERTIA * 0.1)
#			collision.collider.play_drag_sound()
	
	#Zoom
	current_zoom = lerp(current_zoom, zoom_factor, delta * ZOOM_SPEED)
	gimbalH.set_scale(Vector3(current_zoom,current_zoom,current_zoom))
	
	# Camera change
	if camera.translation.distance_to(camera_position.translation) > 0.01:
		camera.translation = camera.translation.linear_interpolate(camera_position.translation, delta * 5)
		camera.rotation = camera.rotation.linear_interpolate(camera_position.rotation, delta * 5)


func set_camera_position(pos: String):
	if pos == "DEFAULT":
		camera_position = default_camera_position
	elif pos == "AIM":
		camera_position = aim_camera_postion
	elif pos == "AIM_WEAPON":
		camera_position = aim_weapon_camera_postion

#func _physics_process_wird(delta):
#	# Horizontal Translation ----------------------
#	if Input.is_action_just_pressed("move_left"):
#		h_rot = lerp(player.rotation.y, player.rotation.y + deg2rad(90), 1)
#		print("new hrot left:", h_rot)
#	elif Input.is_action_just_pressed("move_right"):
#		h_rot = lerp(player.rotation.y, player.rotation.y - deg2rad(90), 1)
#		print("new hrot right:", h_rot)
##	elif Input.is_action_pressed("move_backward"):
##		h_rot += 180
#
#	if Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward"):
#
##		strafe_dir = direction
#		var front_back = 1 if Input.is_action_pressed("move_forward") else -1
#		direction = -player.global_transform.basis.z.normalized() * front_back
#
##		if not Input.is_action_pressed("run"):
#		movement_speed = RUN_SPEED
##		else:
##			movement_speed = WALK_SPEED
#
#	else:
#		movement_speed = 0
##		strafe_dir = Vector3.ZERO
#
#	velocity = lerp(velocity, direction * movement_speed, delta * ACCELERATION)
#
#	# Body rotation
##	var angle_dir_rot = atan2(-direction.x, -direction.z) - player.rotation.y
#
#	if (abs(player.rotation.y - h_rot)) > 0.0001:
#		var lerp_rot = lerp_angle(player.rotation.y, h_rot,delta * ANGULAR_ACCELERATION * 1)
#		player.rotation.y = lerp_rot
#
#	# Camera rotation
##	gimbalH.rotate_y(deg2rad(-mouse_rotation.x)*delta*MOUSE_SENSITIVITY)
##	gimbalV.rotate_x(deg2rad(-mouse_rotation.y)*delta*MOUSE_SENSITIVITY)
##	gimbalV.rotation_degrees.x = clamp(gimbalV.rotation_degrees.x, -MAX_ROTATION, MAX_ROTATION)
##	mouse_rotation = Vector2()
#
#	# Vertical velocity
#	if not player.is_on_floor():
#		vertical_velocity += GRAVITY * delta
#	else:
#		vertical_velocity = 0
#
#	# Main movement
#	velocity = player.move_and_slide(velocity + Vector3.DOWN * vertical_velocity, Vector3.UP)
#
#	#Zoom
##	current_zoom = lerp(current_zoom, zoom_factor, delta * ZOOM_SPEED)
##	gimbalH.set_scale(Vector3(current_zoom,current_zoom,current_zoom))
