extends Control

onready var lost_screen = $LostScreen
onready var lost_sound = $LostScreen/DefeatSound
onready var win_screen = $WinScreen
onready var win_sound = $WinScreen/WinSound

func _ready():
	pass
	
func on_lost():
	lost_sound.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	yield(get_tree().create_timer(2), "timeout")
	lost_screen.show()
	yield(get_tree().create_timer(2), "timeout")
	get_tree().paused = true

func on_win():
	win_sound.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	yield(get_tree().create_timer(2), "timeout")
	win_screen.show()
	yield(get_tree().create_timer(2), "timeout")
	get_tree().paused = true
	
func _input(event):
	if event.is_action_released("ui_cancel"):
		$PauseScreen.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true
	

func _on_PlayAgainButton_pressed():
	get_tree().reload_current_scene()

func _on_MainMenuButton_pressed():
	get_tree().paused = false	
	get_tree().change_scene("res://ui/scenes/MainMenu.tscn")


func _on_ResumeButton_pressed():
	$PauseScreen.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
