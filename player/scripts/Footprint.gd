extends MeshInstance

export(float, 0, 300) var LIFETIME: float = 120


func _ready():
	pass
	

func _physics_process(delta):
	var material: SpatialMaterial = mesh.surface_get_material(0)
	material.albedo_color.a -= delta/LIFETIME
	
	if material.albedo_color.a <= 0:
		call_deferred("queue_free")
