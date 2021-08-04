extends Spatial


func _ready():
	for particle in get_children():
#		particles_instance.lifetime = 0.1
		particle.set_one_shot(true)
		particle.set_emitting(true)
		(particle as Particles).speed_scale = 100
#		self.add_child(particles_instance)
