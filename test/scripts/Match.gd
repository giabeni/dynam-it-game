extends Spatial

class_name Match

onready var player = $Player
onready var npcs = $Map/Navigation/NPCs
onready var ui = $PlayerUI
onready var timer = $MatchTimer
onready var procedural_map = $Map

export var GOLD_TARGET = 32
export var NPCS_COUNT = 10
export var ENEMIES_COUNT = 0
export var SEED = false
export var MAIN_SCENE: PackedScene
export var SPAWN_NPCS_TIMER_ACTIVE = true

var npcs_dead = 0
var npcs_count = 0
var npc_miners: Array = []
var state = MatchState.STARTED
var room


enum MatchState {
	STARTED,
	WIN,
	LOST,
}

func _ready():
	get_tree().paused = false
	if not SEED:
		randomize()
	else:
		seed(SEED)
	procedural_map.NPCS_COUNT = NPCS_COUNT
	ui.gold_target = GOLD_TARGET
	player.connect("on_died", $EndScreens, "on_lost")
	player.connect("on_gold_collected", self, "on_gold_collected")
	
		
func _process(delta):
	yield(get_tree().create_timer(0.5), "timeout")
	ui.set_timer(round(timer.time_left))


func _randomize_miners_locations():
	if npcs.get_child_count() > 0:
		# Takes a random NPC and makes it the player location
		var random_index = randi() % npcs.get_child_count()
		var random_npc = npcs.get_child(random_index)
		player.global_transform.origin = random_npc.global_transform.origin
		random_npc.queue_free()


func spawn_remote_player(username, room_spot):
	var new_player = procedural_map.spawn_remote_player(username, room_spot)
	

func start_match():
	$MatchTimer.start()
	$NPCSpawnTimer.start()
	

func configure_npcs_signals():
	_randomize_miners_locations()
	
	npcs_count = npcs.get_child_count()
	ui.set_npcs_count(npcs.get_child_count())
	npc_miners.append(player)
	for npc in npcs.get_children():
		set_npc_signals(npc)


func set_npc_signals(npc):
	npc.connect("on_died", self, "on_npc_died")
	npc_miners.append(npc)
		


func on_npc_died():
	npcs_dead += 1
	ui.increment_npc_dead_count()
#	if state == MatchState.STARTED and npcs_alive <= 0:
#		$EndScreens.on_win()
		
func on_gold_collected():
	if player.gold >= GOLD_TARGET and state == MatchState.STARTED :
		$EndScreens.on_win()
		state = MatchState.WIN

func _on_MatchTimer_timeout():
	return
	if state == MatchState.STARTED and player.gold >= GOLD_TARGET:
		$EndScreens.on_win()
	else:
		$EndScreens.on_lost()
		
func show_UIs():
	ui.show()		

	
func increment_npc_count():
	ui.increment_npc_count()
	

func _input(event):
	if event.is_action_released("toggle_fullscreen"):
		OS.window_fullscreen = not OS.window_fullscreen
