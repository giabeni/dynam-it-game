extends RigidBody

class_name Weapon

export(String) var TYPE = "PICKAXE"
export(float) var DURATION = 30
export(String) var ICON_PATH = "res://weapons/icons/pickaxe.png"

onready var anim_player: AnimationPlayer = $AnimationPlayer
onready var damage_free_timer: Timer = $DamageFreeTimer
onready var damage_area: Area = $DamageArea
onready var collectable_area: Area = $CollectableArea
onready var outline: MeshInstance = $MeshInstance/Outline
onready var hitpoint = $MeshInstance
onready var hit_sound: AudioStreamPlayer3D = $HitSound

enum States {
	COLLECTABLE,
	EQUIPED,
	ATTACKING
}

var state = States.COLLECTABLE
var player

func _ready():
	print("PICKAXEEE")
	if state == States.COLLECTABLE:
		global_translate(Vector3.UP)
		collectable_area.set_deferred("monitoring", true)
		damage_area.set_deferred("monitoring", false)
	elif state == States.EQUIPED:
		anim_player.play("Equiped")
		outline.hide()
		$AnimationPlayer.play("Equiped")
		collectable_area.set_deferred("monitoring", false)
		damage_area.set_deferred("monitoring", true)

func equip(_player: Spatial):
	state = States.EQUIPED
	player = _player


func _on_CollectableArea_body_entered(body: Spatial):
	if  state == States.COLLECTABLE and body.is_in_group("Miners") and body.has_method("on_weapon_collected") and body.is_alive():
		$AnimationPlayer.play("Collected")
		body.on_weapon_collected(TYPE)
		yield(get_tree().create_timer(0.7), "timeout")
		call_deferred("queue_free")
		

func start_attack(duration = 2, delay = 0):
	if state != States.EQUIPED:
		return
	
	if delay > 0:
		yield(get_tree().create_timer(delay), "timeout")
		
	state = States.ATTACKING
	yield(get_tree().create_timer(duration), "timeout")
	state = States.EQUIPED


func _on_DamageArea_body_entered(body: Spatial):
	
	if body.get_instance_id() == player.get_instance_id():
		return
	
	if not state == States.ATTACKING or not damage_free_timer.is_stopped():
		return
		
	if not body.is_in_group("Miners") and not body.is_in_group("Obstacles"):
		return
		
	if body.has_method("on_weapon_hit") and body.is_alive():
		body.on_weapon_hit()
		damage_free_timer.start()
	elif body.has_method("destroy"):
		body.destroy()
		damage_free_timer.start()
	
	hit_sound.play()
		
