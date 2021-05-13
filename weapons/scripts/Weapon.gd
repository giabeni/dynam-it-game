extends RigidBody

class_name Weapon

export(String) var TYPE = "PICKAXE"
export(float) var DURATION = 15
export(String) var ICON_PATH = "res://weapons/icons/pickaxe.png"
export(bool) var THROWABLE = false
export(bool) var DELETE_AFTER_TIMER = true
export(float) var ATTACK_INTERVAL = 1.0

onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var damage_free_timer: Timer = $DamageFreeTimer
onready var damage_area: Area = $DamageArea
onready var collectable_area: Area = $CollectableArea
onready var outline: MeshInstance = $MeshInstance/Outline
onready var hitpoint = $MeshInstance
onready var metal_sound: AudioStreamPlayer3D = $MetalSound
onready var wall_sound: AudioStreamPlayer3D = $WallSound
onready var hit_flesh_sound: AudioStreamPlayer3D = $BloodSound
onready var wall_particles: Particles = $WallParticles
onready var wall_particles2: Particles = $WallParticles2
onready var blood_particles: Particles = $BloodParticles
onready var hit_point = $HitPoint

enum States {
	COLLECTABLE,
	EQUIPED,
	ATTACKING
}

var state = States.COLLECTABLE
var player
var last_wall_particles
var outline_color = Color.white

func _ready():
	
	last_wall_particles = wall_particles2
	
	if state == States.COLLECTABLE:
		global_translate(Vector3.UP)
		mode = MODE_STATIC
		collectable_area.set_deferred("monitoring", true)
		damage_area.set_deferred("monitoring", false)
	elif state == States.EQUIPED:
		mode = MODE_RIGID
		anim_player.play("Equiped")
		outline.hide()
		$AnimationPlayer.play("Equiped")
		collectable_area.set_deferred("monitoring", false)
		damage_area.set_deferred("monitoring", true)


func equip(_player: Spatial):
	self.add_collision_exception_with(_player)
	mode = MODE_RIGID
	state = States.EQUIPED
	player = _player


func _on_CollectableArea_body_entered(body: Spatial):
	if state == States.COLLECTABLE and body.is_in_group("Miners") and body.has_method("on_weapon_collected") and body.is_alive():
		state = States.EQUIPED
		$AnimationPlayer.play("Collected")
		body.on_weapon_collected(TYPE)
		yield(get_tree().create_timer(0.7), "timeout")
		queue_free()
		

func start_attack(duration = 2, delay = 0):
	if state != States.EQUIPED:
		return
	
	if delay > 0:
		yield(get_tree().create_timer(delay), "timeout")
	
	if is_instance_valid(damage_free_timer):
		damage_free_timer.stop()
	state = States.ATTACKING
	yield(get_tree().create_timer(duration), "timeout")
	state = States.EQUIPED


func _on_DamageArea_body_entered(body: Spatial):
	
	
	if body.get_instance_id() == player.get_instance_id():
		return
	
	if not state == States.ATTACKING or not damage_free_timer.is_stopped():
		return
		
	if not can_damage():
		return
		
	if body.is_in_group("Terrain"):
		if last_wall_particles.get_instance_id() == wall_particles2.get_instance_id():
			wall_particles.emitting = true
			last_wall_particles = wall_particles
		elif last_wall_particles.get_instance_id() == wall_particles.get_instance_id():
			wall_particles2.emitting = true
			last_wall_particles = wall_particles2
			
		if not wall_sound.playing:
			wall_sound.pitch_scale = rand_range(0.9, 1.2)
			wall_sound.play()
		
		return

	if not body.is_in_group("Miners") and not body.is_in_group("Obstacles"):
		return
		
	if body.has_method("on_weapon_hit") and body.is_alive():
		var point_direction = hit_point.global_transform.origin.direction_to(body.body_hitpoint.global_transform.origin)
		var player_direction = player.global_transform.origin.direction_to(body.global_transform.origin)
		var impulse = (point_direction + player_direction).normalized() * 1500
		impulse.y = 800
		body.on_weapon_hit(impulse)
		damage_free_timer.start()
		state = States.EQUIPED
		blood_particles.emitting = false
		blood_particles.emitting = true
		hit_flesh_sound.play()
		if THROWABLE and self["thrown"] and self.has_method("_on_thrown_hit"):
			self.call("_on_thrown_hit", false)
			
	elif body.has_method("destroy"):
		body.destroy()
		damage_free_timer.start()
		state = States.EQUIPED
		metal_sound.pitch_scale = rand_range(0.1, 0.8)
		metal_sound.play()
		if THROWABLE and self["thrown"] and self.has_method("_on_thrown_hit"):
			self.call("_on_thrown_hit", false)
		

func can_damage():
	return true


func set_outline_color(color: Color):
	(outline.get_active_material(0) as SpatialMaterial).albedo_color = color
	(outline.get_active_material(0) as SpatialMaterial).emission = color
	outline_color = color
