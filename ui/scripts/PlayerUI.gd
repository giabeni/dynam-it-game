extends Control

onready var gold_btn: Button = $VBoxContainer/TopBar/GoldContainer/GoldButton
onready var timer_btn: Button = $VBoxContainer/TopBar/GoldContainer2/TimerButton
onready var npcs_btn: Button = $VBoxContainer/TopBar/GoldContainer3/NPCs

var gold_target = 20
var npcs_count = 0
var npcs_alive = 0

func set_gold(gold: int):
	gold_btn.text = str(gold) + "/" + str(gold_target) + "kg"

func set_npcs_alive(alive: int):
	npcs_btn.text = str(npcs_count - alive) + "/" + str(npcs_count)

func set_timer(secs: int):
	timer_btn.text = str(secs) + " s"
