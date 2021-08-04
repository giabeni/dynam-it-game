extends MeshInstance

export(float, 0, 300) var LIFETIME: float = 120
export(float) var PERIOD: float = 0.25
export(float) var DECAY: float = 0.25

onready var timer: Timer = Timer.new()

var material: SpatialMaterial

func _ready():
	timer.wait_time = PERIOD
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.connect("timeout", self, "_on_interval_timeout")
	material = mesh.surface_get_material(0)
	

func _on_interval_timeout():
	material.albedo_color.a -= DECAY/LIFETIME
	
	if material.albedo_color.a <= 0:
		call_deferred("queue_free")
