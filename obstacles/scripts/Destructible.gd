extends RigidBody

class_name Destructible

onready var hitpoints: Spatial = $Hitpoints

export(Array, PackedScene) var ITEMS_SCENES = []
export(float, 0, 1) var ITEM_PROB = 1
export(float, 0, 10) var TIME_TO_EXPLODE = 1.14
export(float) var MIN_IMPACT_TO_DESTROY = 2000

var destroyed = false
var thrown = false
var inner_area: Area
var grab_parent: Spatial = null
var miner_parent = null
var default_parent: Spatial
var bullet_area: Area
var thrown_timer: SceneTreeTimer

var nav_grid_cells = []


signal on_destroyed

func _ready():
	default_parent = get_parent()
	
	if has_node("InnerArea"):
		inner_area = get_node("InnerArea")
		
	if has_node("BulletArea"):
		bullet_area = get_node("BulletArea")
		bullet_area.connect("body_entered", self, "_on_BulletArea_body_entered")

func _physics_process(delta):
#	if is_instance_valid(grab_parent):
#		self.global_transform = grab_parent.global_transform
	pass
		


func destroy():
	if not destroyed:
#		print("Destroying...", name)
		$AnimationPlayer.play("Explode")
		destroyed = true
		emit_signal("on_destroyed", nav_grid_cells)
		
		if _should_spawn_item():
			var item = _get_random_item()
			get_parent().add_child(item)
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
	

func set_grabbed_by(grab_node: Spatial, miner: KinematicBody):
	if not is_in_group("Grabbables"):
		return
	
	miner_parent = miner
	
	if not is_instance_valid(grab_node):
		grab_parent.remove_child(self)
		default_parent.add_child(self)
		self.mode = RigidBody.MODE_RIGID
		self.global_transform = grab_parent.global_transform
		grab_parent = null
	else:
		if thrown:
			thrown_timer.disconnect("timeout", self, "_on_thrown_timer_timeout")
		grab_parent = grab_node
		self.mode = RigidBody.MODE_RIGID
		thrown = false
		bullet_area.monitoring = false
		get_parent().remove_child(self)
		grab_node.add_child(self)
		self.global_transform = grab_parent.global_transform
	
		

func throw(impulse: Vector3):
	if bullet_area:
		axis_lock_angular_x = false
		axis_lock_angular_y = false
		axis_lock_angular_z = false
		bullet_area.monitoring = true
		thrown = true
		self.apply_central_impulse(impulse)
		thrown_timer = get_tree().create_timer(2)
		thrown_timer.connect("timeout", self, "_on_thrown_timer_timeout")
		

func _on_thrown_timer_timeout():
	thrown = false
	bullet_area.monitoring = false
	miner_parent = null
	

func _on_BulletArea_body_entered(body):
	if not thrown:
		return
		
	var impact = self.linear_velocity.length_squared() * self.mass
	if body.is_in_group("Obstacles") and body.get_instance_id() != self.get_instance_id():
		print("Impact = ", impact)
		if impact > body.MIN_IMPACT_TO_DESTROY:
			body.destroy()
		if impact > MIN_IMPACT_TO_DESTROY:
			print("body = ", body.name)
			destroy()
	elif body.is_in_group("Miners") and body.is_alive() and body.get_instance_id() != miner_parent.get_instance_id():
		if impact > MIN_IMPACT_TO_DESTROY:
			print("body = ", body.name)
			destroy()
