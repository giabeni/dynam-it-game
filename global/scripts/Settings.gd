extends Node

var controller_input = false

var JOYSTICK = {
	"CAMERA_SENSITIVITY": Vector2(10, 7),
}
var MOUSE = {
	"CAMERA_SENSITIVITY": Vector2(8, 8),
}

func _input(event):
	pass
#	if event.is_action_pressed("switch_control"):
#		controller_input = not controller_input
