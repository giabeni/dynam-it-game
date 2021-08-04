extends RigidBody

var scale_ratio = 0.98

func on_timer_timeout():
	self.scale = scale_ratio * self.scale
	
