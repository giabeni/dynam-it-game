extends Control

onready var start_btn: TextureButton = $MarginContainer/VBoxContainer/HBoxContainer/MenuList/Line1/StartButton
onready var how_to_play_btn: TextureButton = $MarginContainer/VBoxContainer/HBoxContainer/MenuList/Line2/HowToPlayButton
onready var credits_btn: TextureButton = $MarginContainer/VBoxContainer/HBoxContainer/MenuList/Line3/CreditsButton
onready var exit_btn: TextureButton = $MarginContainer/VBoxContainer/Footer/ExitButton
onready var sound_btn: TextureButton = $MarginContainer/VBoxContainer/TopBar/TopRight/SoundButton

onready var hover_sound: AudioStreamPlayer = $HoverSound
onready var click_sound: AudioStreamPlayer = $ClickSound
onready var confirm_sound: AudioStreamPlayer = $ConfirmSound


func _ready():
	pass
	
	
func _process(delta):
	pass
