extends RigidBody

class_name Destructible

onready var hitpoints: Spatial = $Hitpoints
onready var contact_sound_timer: SceneTreeTimer = get_tree().create_timer(0)
onready var scaler_script = load("res://test/scripts/ScalerTimer.gd")
onready var collision_shape = $CollisionShape

export(Array, PackedScene) var ITEMS_SCENES = [
	preload("res://weapons/scenes/Pickaxe.tscn"),
	preload("res://weapons/scenes/MiniAxe.tscn"),
	preload("res://powerups/scenes/RedDiamond.tscn"),
	preload("res://powerups/scenes/RedDiamond.tscn"),
	preload("res://powerups/scenes/RedDiamond.tscn"),
	preload("res://powerups/scenes/RedDiamond.tscn"),
	preload("res://powerups/scenes/BlueDiamond.tscn"),
	preload("res://powerups/scenes/BlueDiamond.tscn"),
	preload("res://powerups/scenes/BlueDiamond.tscn"),
	preload("res://powerups/scenes/BlueDiamond.tscn"),
	preload("res://powerups/scenes/Dinamite.tscn"),
	preload("res://powerups/scenes/Dinamite.tscn"),
	preload("res://powerups/scenes/Dinamite.tscn"),
	preload("res://powerups/scenes/Dinamite.tscn"),
]
export(float, 0, 1) var ITEM_PROB = 1
export(float, 0, 10) var TIME_TO_EXPLODE = 7
export(float) var MIN_IMPACT_TO_DESTROY = 2000
export(float) var FRAGMENTS_FORCE = 250

var destroyed = false
var thrown = false
var inner_area: Area
var grab_parent: Spatial = null
var miner_parent = null
var default_parent: Spatial
var bullet_area: Area
var hit_sounds = []
var hit_sound_index = 0
var outline: MeshInstance
var thrown_timer: SceneTreeTimer
var dust_particles: Particles
var drag_sound: AudioStreamPlayer3D
var drag_timer: Timer
var item_scene: PackedScene = null
var rocks_falling_sound: AudioStreamPlayer3D

var src_rb: RigidBody
export(NodePath) var mesh_path: NodePath = "./MasterBrush004"
var src_mesh: MeshInstance
var fragments_container: Spatial
var fragments: Array = []
var fragments_grid_size_x = 1.2
var fragments_grid_size_y = 1.2


var nav_grid_cells = []


signal on_destroyed(cells)
signal on_will_destroy(object)

func _ready():
	default_parent = get_parent()
	
	if has_node("InnerArea"):
		inner_area = get_node("InnerArea")
		
	if has_node("BulletArea"):
		bullet_area = get_node("BulletArea")
		bullet_area.connect("body_entered", self, "_on_BulletArea_body_entered")
		
	if has_node("HitSounds"):
		hit_sounds = get_node("HitSounds").get_children()
		hit_sounds.shuffle()
		
	if has_node("Outline"):
		outline = get_node("Outline")
		
	if has_node("DustParticles"):
		dust_particles = get_node("DustParticles")
		
	if has_node("DragSound"):
		drag_sound = get_node("DragSound")
		drag_timer = Timer.new()
		drag_timer.wait_time = 0.5
		drag_timer.one_shot = true
		add_child(drag_timer)
		drag_timer.connect("timeout", self, "on_drag_timeout")
		
	if _should_spawn_item():
		item_scene = _get_random_item()
			
	if has_node("FragmentParticles"):
		$FragmentParticles.amount = 40
	
	if has_node("RocksFallingSound"):
		rocks_falling_sound = $RocksFallingSound
		
	if has_node("VisibilityEnabler"):
		$VisibilityEnabler.connect("screen_entered", self, "_on_screen_entered")
		$VisibilityEnabler.connect("screen_exited", self, "_on_screen_exited")
			


func _physics_process(delta):
	if thrown and hit_sounds.size() > 0:
		for body in get_colliding_bodies():
			_on_contact(body)


func destroy():
	if not destroyed:
		emit_signal("on_will_destroy", self)
		
#		if has_node(mesh_path):
#			_generate_fragments()
#			_blow_fragments()
		
#		print("Destroying...", name)
		$AnimationPlayer.play("Explode")
		destroyed = true
		emit_signal("on_destroyed", nav_grid_cells)
		get_tree().call_group("Player", "on_obstacle_destroyed", self.global_transform.origin)
		
		if has_node("RocksFallingSound"):
			rocks_falling_sound.pitch_scale = rand_range(0.8, 1.2)
			rocks_falling_sound.unit_size = 5
			rocks_falling_sound.play()
		
		if item_scene != null:
			var item = item_scene.instance()
			get_parent().add_child(item)
			item.global_transform.origin = self.global_transform.origin
			item.global_transform.origin.y = 1.2
			
#			print("Item spawned: ", item)
		yield(get_tree().create_timer(1.14),"timeout")
		collision_shape.disabled = true

		yield(get_tree().create_timer(TIME_TO_EXPLODE - 1.14),"timeout")
		call_deferred("queue_free")

	
func _should_spawn_item():
	return ITEMS_SCENES.size() > 0 and randf() < ITEM_PROB

	
func _get_random_item():
	var random_index = int(round(rand_range(0, ITEMS_SCENES.size() - 1)))
	var scene: PackedScene = ITEMS_SCENES[random_index]
	return scene


func is_overlapping_body():
	if not is_instance_valid(inner_area):
		return false
	
	for body in inner_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id():
			return true
	return false
	

func is_blocking_npc():
	if not is_instance_valid(inner_area):
		return false
	# Scales area to check for NPCS
	inner_area.scale = Vector3(5, 5, 5)
	for body in inner_area.get_overlapping_bodies():
		if body.get_instance_id() != self.get_instance_id() and body.is_in_group("Miners"):
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
		if is_instance_valid(outline):
			outline.hide()
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
		
	if body.get_instance_id() == self.get_instance_id() or body.get_instance_id() == miner_parent.get_instance_id():
		return
	

	var impact = self.linear_velocity.length_squared() * self.mass
	if body.is_in_group("Obstacles"):
		if impact > body.MIN_IMPACT_TO_DESTROY:
			body.destroy()
		if impact > MIN_IMPACT_TO_DESTROY:
			destroy()
	elif body.is_in_group("Miners") and body.is_alive():
		if impact > MIN_IMPACT_TO_DESTROY:
			destroy()
		if impact > body.MIN_IMPACT_TO_BE_DIZZY:
			body.set_dizzy(true)
			

func _on_contact(body):
	if not thrown:
		return
		
	if body.get_instance_id() == self.get_instance_id() or body.get_instance_id() == miner_parent.get_instance_id():
		return
		
	if contact_sound_timer.time_left > 0:
		return
	
	_play_hit_sound()
	contact_sound_timer = get_tree().create_timer(0.2)
	

func _play_hit_sound():
	if hit_sounds.size() <= 0:
		return
	if is_instance_valid(dust_particles):
		dust_particles.emitting = true
	(hit_sounds[hit_sound_index] as AudioStreamPlayer3D).pitch_scale = rand_range(0.9, 1.4)
	(hit_sounds[hit_sound_index] as AudioStreamPlayer3D).play()
	var volume = 400 * (linear_velocity.length() / 10)
	(hit_sounds[hit_sound_index] as AudioStreamPlayer3D).unit_size = volume
	hit_sound_index += 1
	if hit_sound_index >= hit_sounds.size():
		hit_sound_index = 0


func play_drag_sound():
	if not drag_sound.playing:
		drag_sound.play()
	drag_timer.start()


func on_drag_timeout():
	if drag_sound.playing:
		drag_sound.stop()


func _generate_fragments():
#	yield(get_tree().create_timer(2), "timeout")
	var splerger = Splerger.new()
	
	fragments_container = Spatial.new()
	fragments_container.name = "Fragments"
	get_parent().add_child(fragments_container)
	
	src_mesh = get_node(mesh_path)
	src_rb = self
	
	splerger.split(src_mesh, fragments_container, fragments_grid_size_x, fragments_grid_size_y, false, true)
#	src_rb.queue_free()
	
	fragments_container.hide()
	
	var material_path = "res://tiles/materials/RockWithFresnel.tres"
	var material = load(material_path)
	
	var meshes = fragments_container.get_children()
	
	
	for mesh in meshes:
		var mesh_transform = mesh.global_transform
		(mesh as MeshInstance).material_override = material
		
		var rb = RigidBody.new()
		rb.can_sleep = false
		rb.sleeping = false
		rb.mass = rand_range(3, 5)
		rb.linear_damp = 2
		rb.angular_damp = 2
		rb.global_transform = mesh_transform
		
		var poly_shape: ConvexPolygonShape = ConvexPolygonShape.new()
		poly_shape = ((mesh as MeshInstance).mesh.create_convex_shape())
		poly_shape.margin = 0.005
		var owner_id = rb.create_shape_owner(rb)
		rb.shape_owner_add_shape(owner_id, poly_shape)
		rb.set_script(scaler_script)
		
		fragments_container.add_child(rb)
		
		fragments_container.remove_child(mesh)
		rb.add_child(mesh)
		
		var col: CollisionShape = CollisionShape.new()
		col.shape = poly_shape
		rb.add_child(col)
		
		fragments.append(rb)
	

func _blow_fragments():
	if fragments.size() > 0:
		fragments_container.show()
		var explosion_center = src_rb.global_transform.origin
		for rb in fragments:
			var direction: Vector3 = rb.global_transform.origin - explosion_center
			direction = direction.normalized()
			
			(rb as RigidBody).apply_impulse(rb.to_local(explosion_center), direction * FRAGMENTS_FORCE)
			var timer = Timer.new()
			timer.autostart = true
			timer.wait_time = 0.1
			timer.one_shot = false
			timer.process_mode = Timer.TIMER_PROCESS_PHYSICS
			rb.add_child(timer)
			timer.connect("timeout", rb, "on_timer_timeout")
			

func _on_screen_entered():
	pass


func _on_screen_exited():
	pass
