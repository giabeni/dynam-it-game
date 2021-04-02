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

enum State {
	CARRY,
	DROPPED,
	EXPLODED
}

var state = State.CARRY

func _physics_process(delta):
	if state == State.DROPPED:
		sparks.translate(Vector3.RIGHT * delta * 0.025)

func drop():
	set_as_toplevel(true)
	mass = 20
	mode = MODE_RIGID
	state = State.DROPPED
	timer.start()
	spark1.emitting = true
	spark2.emitting = true
	spark3.emitting = true
	light.light_energy = 1.5


func _explode():
	mesh.hide()
	sparks.hide()
	explosion.emitting = true
	explosion2.emitting = true
	light.omni_range = 32
	light.light_energy = 4
	state = State.EXPLODED
	emit_signal("bomb_exploded")
	var duration = explosion.lifetime / explosion.speed_scale
	yield(get_tree().create_timer(duration), "timeout")
	call_deferred("queue_free")


func _on_Timer_timeout():
	_explode()
