extends Control

onready var lost_screen = $LostScreen
onready var lost_sound = $LostScreen/DefeatSound
onready var win_screen = $WinScreen
onready var win_sound = $WinScreen/WinSound
onready var loading_screen = $LoadingScreen
onready var loading_bar = $LoadingScreen/CenterContainer2/VBoxContainer/CenterContainer/LoadingProgress
onready var loading_label = $LoadingScreen/CenterContainer2/VBoxContainer/CenterContainer2/LoadingLabel

var target_loading_progress = 0
var target_alpha = 1

func _ready():
	pass
	
func _process(delta):
	loading_bar.value = lerp(loading_bar.value, target_loading_progress, delta * 0.5)
	loading_screen.modulate.a = lerp(loading_screen.modulate.a, target_alpha, delta * 2)
	if loading_screen.modulate.a <= 0.01:
		loading_screen.hide()
	else:
		loading_screen.show()
	
func on_lost():
	get_parent().state = get_parent().MatchState.LOST
	lost_sound.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	yield(get_tree().create_timer(1.5), "timeout")
	lost_screen.show()
	yield(get_tree().create_timer(10), "timeout")
	get_tree().paused = true

func on_win():
	get_parent().state = get_parent().MatchState.WIN
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
	

func set_loading_screen(progress: float, text: String):
	target_loading_progress = progress
	loading_label.text = text.to_upper() + "(" + str(progress) + ")%"
	if progress >= 100:
		$"../PlayerUI".show()
		target_alpha = 0
