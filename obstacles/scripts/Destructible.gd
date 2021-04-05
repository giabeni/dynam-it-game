extends StaticBody

onready var hitpoints: Spatial = $Hitpoints

export(Array, PackedScene) var ITEMS_SCENES = []

var destroyed = false

func destroy():
	if not destroyed:
#		print("Destroying...", name)
		$AnimationPlayer.play("Explode")
		destroyed = true
		
		if _should_spawn_item():
			var item = _get_random_item()
			get_parent().call_deferred("add_child", item)
#			print("Item spawned: ", item)

		yield(get_tree().create_timer(1.14),"timeout")
		call_deferred("queue_free")
	
func _should_spawn_item():
	return ITEMS_SCENES.size() > 0
	
func _get_random_item():
	var random_index = int(round(rand_range(0, ITEMS_SCENES.size() - 1)))
	var scene: PackedScene = ITEMS_SCENES[random_index]
	var item = scene.instance()
	item.global_transform.origin = self.global_transform.origin
	return item
