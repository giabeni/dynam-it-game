extends RigidBody

class_name Bomb

signal bomb_exploded

onready var timer: Timer = $Timer
onready var spark1: Particles = $Sparks/Spark
onready var spark2: Particles = $Sparks/Spark2
onready var spark3: Particles = $Sparks/Spark3
onready var sparks: Spatial = $Sparks
onready var light: OmniLight = $Light
onready var explosion: Particles = $Explosion
onready var explosion2: Particles = $Explosion2
onready var mesh = $tnt_pile
onready var explosion_area = $DamageArea
onready var anim_player: AnimationPlayer = $AnimationPlayer

enum State {
	CARRY,
	DROPPED,
	EXPLODED
}

var state = State.CARRY

func _ready():
#	explosion.hide()
#	explosion2.hide()
#	sparks.hide()
#	explosion.emitting = true
#	explosion2.emitting = true
#	spark1.emitting = true
#	spark2.emitting = true
#	spark3.emitting = true
#	yield(get_tree().create_timer(0.5), "timeout")
#	explosion.emitting = false
#	explosion2.emitting = false
#	spark1.emitting = false
#	spark2.emitting = false
#	spark3.emitting = false
#	explosion.show()
#	explosion2.show()
#	sparks.show()
	pass
	

func _physics_process(delta):
	if state == State.DROPPED:
		sparks.translate(Vector3.RIGHT * delta * 0.025)

func drop():
	set_as_toplevel(true)
	mass = 20
	mode = MODE_RIGID
	state = State.DROPPED
	timer.start()
	anim_player.play("Drop")
	light.light_energy = 1.5


func _explode():
	state = State.EXPLODED
	mesh.hide()
	sparks.hide()
	anim_player.play("Explode")
	emit_signal("bomb_exploded")


func _on_Timer_timeout():
	_explode()


func _on_DamageArea_body_entered(body: Spatial):
	if state == State.EXPLODED and body.has_method("on_explosion_hit"):
		var space = get_world().direct_space_state
		var ray_collision = space.intersect_ray(global_transform.origin, body.global_transform.origin, [], 1)
		if not ray_collision.empty() and ray_collision.collider.get_instance_id() == body.get_instance_id():
			body.on_explosion_hit()
	

func _on_animation_finished(anim_name):
	if anim_name == "Explode":
		call_deferred("queue_free")
		
