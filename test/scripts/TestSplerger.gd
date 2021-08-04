extends Spatial

onready var splerger = Splerger.new()
onready var fragments = $Fragments
onready var scaler_script = load("res://test/scripts/ScalerTimer.gd")

var rbs = []
var grid_size = 1.2
var grid_size_y = 1.2

func _ready():
	
	pass
	

func _explode(src_rb, src_mesh, force):
	var dest = Spatial.new()
	fragments.add_child(dest)
	var explosion_center = src_rb.global_transform.origin
	
	splerger.split(src_mesh, dest, grid_size, grid_size_y, false, true)
	src_rb.queue_free()
	
	var material_path = "res://tiles/materials/RockWithFresnel.tres"
	
	var meshes = dest.get_children()
	
	var material = load(material_path)
	
	for mesh in meshes:
		var mesh_transform = mesh.global_transform
		(mesh as MeshInstance).material_override = material
		
		var rb = RigidBody.new()
		rb.can_sleep = false
		rb.sleeping = false
		rb.mass = rand_range(3, 5)
		rb.continuous_cd = true
		rb.linear_damp = 2
		rb.angular_damp = 2
		rb.global_transform = mesh_transform
		
		var poly_shape: ConvexPolygonShape = ConvexPolygonShape.new()
		poly_shape = ((mesh as MeshInstance).mesh.create_convex_shape())
		poly_shape.margin = 0.005
		var owner_id = rb.create_shape_owner(rb)
		rb.shape_owner_add_shape(owner_id, poly_shape)
		rb.set_script(scaler_script)
		
		dest.add_child(rb)
		
		dest.remove_child(mesh)
		rb.add_child(mesh)
		
		var col: CollisionShape = CollisionShape.new()
		col.shape = poly_shape
		rb.add_child(col)
		
		rbs.append(rb)

#	for i in range(0, 5):
#		yield(get_tree(), "physics_frame")
	
	for rb in rbs:
		var direction: Vector3 = rb.global_transform.origin - explosion_center
		direction = direction.normalized()
		
		(rb as RigidBody).apply_impulse(rb.to_local(explosion_center) ,direction * force)
		var timer = Timer.new()
		timer.autostart = true
		timer.wait_time = 0.1
		timer.one_shot = false
		timer.process_mode = Timer.TIMER_PROCESS_PHYSICS
		rb.add_child(timer)
		timer.connect("timeout", rb, "on_timer_timeout")
		
	
func _on_RockPillar_on_will_destroy(object):
	_explode(object, object.get_node("MasterBrush004"), 250)
