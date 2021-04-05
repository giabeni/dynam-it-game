extends Spatial

onready var hitpoint = $MeshInstance

export(float) var amount = 1
export(String) var type = "VELOCITY"

func _ready():
	pass


func _on_CollectableArea_body_entered(body: Spatial):
	if body.is_in_group("Miners") and body.has_method("on_powerup_collected") and body.is_alive():
		$AnimationPlayer.play("Collected")
		body.on_powerup_collected(type, amount)
		yield(get_tree().create_timer(0.7), "timeout")
		call_deferred("queue_free")
