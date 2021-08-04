extends Weapon

class_name ThrowableWeapon

onready var boomerang_sound: AudioStreamPlayer3D = $BoomerangSound

var thrown = false

func _ready():
	._ready()
	gravity_scale = 0
	self.THROWABLE = true


func equip(_player: Spatial):
	.equip(_player)
	thrown = false


func throw(direction, force):
	if state == States.EQUIPED and not is_set_as_toplevel() and is_instance_valid(self):
		.start_attack(3, 0)
		var prev_transform = self.global_transform
		self.set_as_toplevel(true)
		thrown = true
		gravity_scale = 1
		self.global_transform = prev_transform
		if is_instance_valid(boomerang_sound):
			boomerang_sound.play()
		apply_central_impulse(direction * force)
		outline.show()
		yield(get_tree().create_timer(3), "timeout")
		state = States.COLLECTABLE
		player._on_WeaponTimer_timeout(true)


func can_damage():
	return not thrown or (linear_velocity.length() > 5 and thrown)


func _on_thrown_hit(should_stop):
	if not wall_sound.playing:
		wall_sound.pitch_scale = rand_range(0.9, 1.2)
		wall_sound.play()
	player._on_WeaponTimer_timeout(true)
	boomerang_sound.stop()
	state = States.COLLECTABLE
	set_outline_color(Color.white)
	collectable_area.set_deferred("monitoring", true)
	damage_area.set_deferred("monitoring", false)
	outline.show()
	if should_stop:
		mode = MODE_STATIC
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		

func _on_MiniAxe_body_entered(body):
	if thrown and state == States.ATTACKING and body.is_in_group("Terrain"):
		_on_thrown_hit(true)
	
