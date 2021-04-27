extends Spatial


onready var blink_timer = $BlinkTimer
onready var light = $Light
onready var anim_player = $AnimationPlayer

func _ready():
	blink_timer.wait_time = rand_range(1, 7)
	blink_timer.start()


func _on_BlinkTimer_timeout():
	anim_player.play("Blink")
