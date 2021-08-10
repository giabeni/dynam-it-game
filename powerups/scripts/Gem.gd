extends Spatial

onready var hitpoint = $MeshInstance

export(float) var amount = 1
export(String) var type = "VELOCITY"

var collected = false

func _ready():
	pass


func _on_CollectableArea_body_entered(body: Spatial):
	if not collected and body.is_in_group("Miners") and body.has_method("on_powerup_collected") and body.is_alive():
		$AnimationPlayer.play("Collected")
		body.on_powerup_collected(type, amount)
		collected = true
		yield(get_tree().create_timer(0.7), "timeout")
		call_deferred("queue_free")

func is_collected():
	return collected
