extends Control

onready var start_btn: TextureButton = $MarginContainer/VBoxContainer/HBoxContainer/MenuList/Line1/StartButton
onready var how_to_play_btn: TextureButton = $MarginContainer/VBoxContainer/HBoxContainer/MenuList/Line2/HowToPlayButton
onready var credits_btn: TextureButton = $MarginContainer/VBoxContainer/HBoxContainer/MenuList/Line3/CreditsButton
onready var exit_btn: TextureButton = $MarginContainer/VBoxContainer/Footer/ExitButton
onready var sound_btn: TextureButton = $MarginContainer/VBoxContainer/TopBar/TopRight/SoundButton

onready var hover_sound: AudioStreamPlayer = $HoverSound
onready var click_sound: AudioStreamPlayer = $ClickSound
onready var confirm_sound: AudioStreamPlayer = $ConfirmSound

var MATCH_SCENE: PackedScene


func _ready():
	MATCH_SCENE = preload("res://map/scenes/ProceduralMap.tscn")

	
func _process(delta):
	pass


func _on_StartButton_pressed():
	get_tree().change_scene_to(MATCH_SCENE)


func _on_ExitButton_pressed():
	get_tree().quit()


func _on_HowToPlayButton_pressed():
	$HowToPlay.show()
	$MarginContainer.hide()


func _on_CreditsButton_pressed():
	$Credits.show()
	$MarginContainer.hide()


func _on_BackButton_pressed():
	$MarginContainer.show()
	$HowToPlay.hide()
	$Credits.hide()
