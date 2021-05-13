extends Node

class_name RoomContainer

enum ClientStatus {
	PENDING,
	ROOM_LOADED,
	READY_TO_START,
	STARTED
}

onready var waiting_screen = $WaitingScreen

var host_id
var players = {}
var usernames = {}
var spots = {}
var room_seed
var created_at
var room_id

var match_instance
var has_match = false
var map_generated = false

const MATCH_SCENE = preload("res://map/scenes/RemoteProceduralMap.tscn")

func _ready():
	rpc_id(1, "set_client_status", ClientStatus.ROOM_LOADED)
	waiting_screen.update_players_list(spots)
	

func set_info(room_info: Dictionary):
	room_id = room_info.room_id
	host_id = room_info.host_id
	created_at = room_info.created_at
	room_seed = room_info.room_seed
	spots = room_info.spots


remote func load_match():
	yield(get_tree(), "idle_frame")
	match_instance = MATCH_SCENE.instance()
	match_instance.room = self
	match_instance.NPCS_COUNT = 2
	match_instance.SEED = room_seed
	has_match = true
	add_child(match_instance)
	match_instance.procedural_map.connect("finished_map_generation", self, "finished_map_generation")


func finished_map_generation():
	map_generated = true
	rpc_id(1, "set_client_status", ClientStatus.READY_TO_START)
	

remote func add_new_player(player_id, username, room_spot):
	print(">> REMOTE: Adding new player ", username, " at spot ", room_spot)
#	if int(player_id) != int(Server.player_id):
	set_spot(username, room_spot)
	waiting_screen.update_players_list(spots)
#		match_instance.spawn_remote_player(username, room_spot)
		

remote func start_match():
	match_instance.procedural_map.start_match()
	rpc_id(1, "set_client_status", ClientStatus.STARTED)
	waiting_screen.hide()
	

func set_spot(username, room_spot):
	spots[username] = room_spot
	waiting_screen.update_players_list(spots)
	

func send_player_state(player_state):
	rpc_unreliable_id(1, "receive_player_state", player_state)


remote func receive_room_state(room_state):
#	print("Timestamp: ", room_state["T"], "  client clock = ", OS.get_system_time_msecs(), "  deviation = ", OS.get_system_time_msecs() - room_state["T"])
#	print("Timestamp: ", room_state["T"], "  client clock = ", Server.client_clock, "  deviation = ", Server.client_clock - room_state["T"])
	if map_generated:
		match_instance.procedural_map.update_map_state(room_state)
