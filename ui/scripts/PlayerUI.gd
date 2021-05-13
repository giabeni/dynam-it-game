extends Control

class_name PlayerUI

onready var gold_btn: Button = $VBoxContainer/TopBar/GoldContainer/GoldButton
onready var timer_btn: Button = $VBoxContainer/TopBar/GoldContainer2/TimerButton
onready var npcs_btn: Button = $VBoxContainer/TopBar/GoldContainer3/NPCs
onready var dynamites_btn: Button = $VBoxContainer/Footer2/Center/HBoxContainer/DynamitesContainer/DynamitesButton
onready var range_btn: Button = $VBoxContainer/Footer2/Center/HBoxContainer/RangeContainer/RangeButton
onready var speed_btn: Button = $VBoxContainer/Footer2/Center/HBoxContainer/SpeedContainer/SpeedButton
onready var powerup_text = $VBoxContainer/Footer/CenterContainer/PowerUpLabel
onready var powerup_timer: Control = $VBoxContainer/Footer2/PowerUpTimer
onready var powerup_timer_progress: ProgressBar = $VBoxContainer/Footer2/PowerUpTimer/PowerUpProgress
onready var powerup_timer_icon: TextureRect = $VBoxContainer/Footer2/PowerUpTimer/PowerUpTimerTexture

var gold_target = 20
var npcs_count = 0
var npcs_dead = 0

func _ready():
#	$VBoxContainer/CenterSpace.rect_min_size.y = OS.window_size.y - $VBoxContainer/TopBar.rect_min_size.y - $VBoxContainer/Footer.rect_min_size.y - $VBoxContainer/Footer.rect_min_size.y
	pass
	
func set_gold(gold: int):
	gold_btn.text = str(gold) + "/" + str(gold_target) + "kg"

func increment_npc_count():
	npcs_count += 1
	npcs_btn.text = str(npcs_dead) + "/" + str(npcs_count)
	
func increment_npc_dead_count():
	npcs_dead += 1
	npcs_btn.text = str(npcs_dead) + "/" + str(npcs_count)

func set_npcs_count(count: int):
	npcs_count = count
	npcs_btn.text = str(npcs_dead) + "/" + str(npcs_count)

func set_npcs_dead(dead: int):
	npcs_dead = dead
	npcs_btn.text = str(npcs_dead) + "/" + str(npcs_count)
	
func set_timer(secs: int):
	timer_btn.text = str(secs) + " s"
	
	
func set_dynamites(dynamites):
	dynamites_btn.text = str(dynamites)
	
func set_range(_range):
	range_btn.text = str(_range)
	
func set_speed(speed):
	speed_btn.text = str(speed)


func show_power_up_text(text: String):
	powerup_text.text = text
	$AnimationPlayer.play("ShowPowerUpText")
	
func set_powerup_timer(icon: String, max_time: float):
	powerup_timer_icon.texture = load(icon)
	powerup_timer_progress.max_value = max_time
	powerup_timer_icon.show()
	powerup_timer_progress.show()
	powerup_timer.show()
	
func set_current_powerup_timer(time: float):
	powerup_timer_progress.value = time
	
	if time <= 0.1:
		powerup_timer.hide()
	
