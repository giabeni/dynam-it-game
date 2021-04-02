extends Spatial

var last_step_index = -1
var footsteps = []
var enabled = true

func _ready():
	randomize()
	footsteps = get_children()

func play_random_footstep():
	if enabled:
		var random_index = round(rand_range(0, footsteps.size() - 1))
		if random_index == last_step_index:
			random_index += 1 if random_index != footsteps.size() - 1 else -1
		
		var random_pitch = rand_range(0.5, 0.8)
		
		if not (footsteps[random_index] as AudioStreamPlayer3D).playing:
			(footsteps[random_index] as AudioStreamPlayer3D).pitch_scale = random_pitch
			(footsteps[random_index] as AudioStreamPlayer3D).play()
