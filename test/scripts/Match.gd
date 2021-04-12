extends Spatial

onready var player = $Player
onready var npcs = $Level1/Navigation/NPCs
onready var ui = $PlayerUI
onready var timer = $MatchTimer

export var GOLD_TARGET = 32
export var MAIN_SCENE: PackedScene

var npcs_alive = 0
var npc_miners: Array = []
var state = MatchState.STARTED


enum MatchState {
	STARTED,
	WIN,
	LOST,
}

func _ready():
	get_tree().paused = false
	randomize()
	npcs_alive = npcs.get_child_count()
	ui.gold_target = GOLD_TARGET
	ui.set_npcs_count(npcs_alive)
	ui.npcs_count = npcs_alive
	player.connect("on_died", $EndScreens, "on_lost")
	player.connect("on_gold_collected", self, "on_gold_collected")
	
	npc_miners.append(player)
	for npc in npcs.get_children():
		npc.connect("on_died", self, "on_npc_died")
		npc_miners.append(npc)
		
	_randomize_miners_locations()
		
func _process(delta):
	yield(get_tree().create_timer(0.5), "timeout")
	ui.set_timer(round(timer.time_left))
	
func _randomize_miners_locations():
	# only change player location with one of the npc miners
	npc_miners.shuffle()
	
	var npc = npc_miners[0]
	var npc_prev_origin = npc.global_transform.origin
	npc.global_transform.origin = player.global_transform.origin
	player.global_transform.origin = npc_prev_origin

func on_npc_died():
	npcs_alive -= 1
	ui.set_npcs_alive(npcs_alive)
	if npcs_alive <= 0:
		$EndScreens.on_win()
		
func on_gold_collected():
	if player.gold >= GOLD_TARGET and state == MatchState.STARTED :
		$EndScreens.on_win()
		state = MatchState.WIN

func _on_MatchTimer_timeout():
	if player.gold >= GOLD_TARGET:
		$EndScreens.on_win()
	else:
		$EndScreens.on_lost()
		

