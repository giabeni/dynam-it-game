extends Node

onready var hover_sound = $HoverSound
onready var click_sound = $ClickSound

func play_hover_sound():
	hover_sound.play()

func play_click_sound():
	click_sound.play()
