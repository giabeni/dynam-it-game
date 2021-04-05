extends Spatial

onready var hitpoint = $MeshInstance

func _ready():
	pass


func _on_CollectableArea_body_entered(body: Spatial):
	if body.is_in_group("Miners") and body.has_method("on_gold_collected") and body.is_alive():
		$AnimationPlayer.play("Collected")
		body.on_gold_collected()
		yield(get_tree().create_timer(0.7), "timeout")
		call_deferred("queue_free")
