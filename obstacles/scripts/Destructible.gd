extends StaticBody

onready var hitpoints: Spatial = $Hitpoints

export(float) var ITEM_PROB = 0.8

var destroyed = false

func destroy():
	if not destroyed:
		print("Destroying...")
		$AnimationPlayer.play("Explode")
		destroyed = true
		yield(get_tree().create_timer(1.14),"timeout")
		call_deferred("queue_free")
		
#		if _should_spawn_item():
#			return
	
func _should_spawn_item():
	return randf() > ITEM_PROB
