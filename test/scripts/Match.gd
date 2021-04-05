extends Spatial

onready var player = $Player
onready var npcs = $Level1/Navigation/NPCs
onready var ui = $PlayerUI
onready var timer = $MatchTimer
onready var lost_screen = $LostScreen
onready var lost_sound = $LostScreen/DefeatSound
onready var win_screen = $WinScreen
onready var win_sound = $WinScreen/WinSound

export var GOLD_TARGET = 20
export var MAIN_SCENE: PackedScene

var npcs_alive = 0

func _ready():
	npcs_alive = npcs.get_child_count()
	ui.gold_target = GOLD_TARGET
	ui.npcs_count = npcs_alive
	player.connect("on_died", self, "on_lost")
	for npc in npcs.get_children():
		npc.connect("on_died", self, "on_npc_died")
		
func _process(delta):
	yield(get_tree().create_timer(0.5), "timeout")
	ui.set_timer(round(timer.time_left))

func on_npc_died():
	npcs_alive -= 1
	ui.set_npcs_alive(npcs_alive)
	if npcs_alive <= 0:
		on_win()

func _on_MatchTimer_timeout():
	if player.gold >= GOLD_TARGET:
		on_win()
	else:
		on_lost()
		
func on_lost():
	$Soundtrack.stop()
	lost_sound.play()
	$Level1.set_physics_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	yield(get_tree().create_timer(2), "timeout")
	lost_screen.show()

func on_win():
	$Soundtrack.stop()
	win_sound.play()
	$Level1.set_physics_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	yield(get_tree().create_timer(2), "timeout")
	win_screen.show()
	

func _on_PlayAgainButton_pressed():
	get_tree().reload_current_scene()

func _on_MainMenuButton_pressed():
	get_tree().change_scene("res://ui/scenes/MainMenu.tscn")
