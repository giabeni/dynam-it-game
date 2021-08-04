extends Spatial

onready var player1 = $View/HBoxContainer/VC1/Viewport/Player1
onready var player2 = $View/HBoxContainer/VC2/Viewport/Player2
onready var npcs = $Map/Navigation/NPCs
onready var ui1 = $View/HBoxContainer/VC1/Viewport/PlayerUI
onready var ui2 = $View/HBoxContainer/VC2/Viewport/PlayerUI2
onready var timer = $MatchTimer
onready var procedural_map = $Map

export var GOLD_TARGET = 32
export var NPCS_COUNT = 10
export var ENEMIES_COUNT = 0
export var SEED = false
export var MAIN_SCENE: PackedScene

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
	ui1.gold_target = GOLD_TARGET
	ui2.gold_target = GOLD_TARGET
	player1.connect("on_died", $EndScreens, "on_lost")
	player1.connect("on_gold_collected", self, "on_gold_collected")
	player2.connect("on_died", $EndScreens, "on_lost")
	player2.connect("on_gold_collected", self, "on_gold_collected")
	
		
func _process(delta):
	yield(get_tree().create_timer(0.5), "timeout")
	ui1.set_timer(round(timer.time_left))
	ui2.set_timer(round(timer.time_left))


func _randomize_miners_locations(player):
	if npcs.get_child_count() > 0:
		# Takes a random NPC and makes it the player1 location
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
	_randomize_miners_locations(player1)
	_randomize_miners_locations(player2)
	
	npcs_count = npcs.get_child_count()
	ui1.set_npcs_count(npcs_count)
	ui2.set_npcs_count(npcs_count)
	npc_miners.append(player1)
	for npc in npcs.get_children():
		set_npc_signals(npc)


func set_npc_signals(npc):
	npc.connect("on_died", self, "on_npc_died")
	npc_miners.append(npc)
		


func on_npc_died():
	npcs_dead += 1
	ui1.increment_npc_dead_count()
	ui2.increment_npc_dead_count()
#	if state == MatchState.STARTED and npcs_alive <= 0:
#		$EndScreens.on_win()
		
func on_gold_collected():
	if player1.gold >= GOLD_TARGET and state == MatchState.STARTED :
		$EndScreens.on_win()
		state = MatchState.WIN
	elif player2.gold >= GOLD_TARGET and state == MatchState.STARTED :
		$EndScreens.on_win()
		state = MatchState.WIN

func _on_MatchTimer_timeout():
	return
	if state == MatchState.STARTED and player1.gold >= GOLD_TARGET:
		$EndScreens.on_win()
	elif state == MatchState.STARTED and player2.gold >= GOLD_TARGET:
		$EndScreens.on_win()
	else:
		$EndScreens.on_lost()
		
func show_UIs():
	ui1.show()
	ui2.show()
	
func increment_npc_count():
	ui1.increment_npc_count()
	ui2.increment_npc_count()
		

