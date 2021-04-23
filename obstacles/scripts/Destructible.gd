extends StaticBody

class_name Destructible

onready var hitpoints: Spatial = $Hitpoints

export(Array, PackedScene) var ITEMS_SCENES = []
export(float, 0, 1) var ITEM_PROB = 1
export(float, 0, 10) var TIME_TO_EXPLODE = 1.14

var destroyed = false
var inner_area: Area


func _ready():
	if has_node("InnerArea"):
		inner_area = get_node("InnerArea")

func destroy():
	if not destroyed:
#		print("Destroying...", name)
		$AnimationPlayer.play("Explode")
		destroyed = true
		
		if _should_spawn_item():
			var item = _get_random_item()
			get_parent().call_deferred("add_child", item)
			item.global_transform.origin = self.global_transform.origin
			
#			print("Item spawned: ", item)

		yield(get_tree().create_timer(TIME_TO_EXPLODE),"timeout")
		call_deferred("queue_free")
	
func _should_spawn_item():
	return ITEMS_SCENES.size() > 0 and randf() < ITEM_PROB

	
func _get_random_item():
	var random_index = int(round(rand_range(0, ITEMS_SCENES.size() - 1)))
	var scene: PackedScene = ITEMS_SCENES[random_index]
	var item = scene.instance()
	return item


func is_overlapping_body():
	if not is_instance_valid(inner_area):
		return false
	
	for body in inner_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id():
			return true
	return false
	

func is_blocking_npc():
	# Scales area to check for NPCS
	inner_area.scale = Vector3(5, 5, 5)
	for body in inner_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id() and body.is_in_group("Miners"):
			print("Obstacle near NPC")
			return true
	return false

func remove_inner_area():
	if not is_instance_valid(inner_area):
		return false
	inner_area.call_deferred("queue_free")
