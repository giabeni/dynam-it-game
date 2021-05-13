extends Node

var network = NetworkedMultiplayerENet.new()
var ip = "127.0.0.1"
var port = 1909

var latency = 0
var latency_array = []
var delta_latency = 0
var client_clock = 0
var decimal_collector : float = 0

var token
var username
var player_id
var should_disconnect = false

var login_screen
var rooms: Rooms

const ROOMS_SCENE = preload("res://server/scenes/Rooms.tscn")

func _ready():
	rooms = ROOMS_SCENE.instance()
	add_child(rooms)


func _process(delta):
	if get_custom_multiplayer() == null:
		return
	if not custom_multiplayer.has_network_peer():
		return
	custom_multiplayer.poll()


func connect_to_server():
	network.create_client(ip, port)
	get_tree().set_network_peer(network)
	
	network.connect("connection_failed", self, "_on_connection_failed")
	network.connect("connection_succeeded", self, "_on_connection_succeeded")
	network.connect("server_disconnected", self, "_on_server_disconnected")


func reconnect_to_server():
	print("SERVER: Trying to reconnect...")
	network = NetworkedMultiplayerENet.new()
	var multiplayer_api = MultiplayerAPI.new()
	network.create_client(ip, port)
	set_custom_multiplayer(multiplayer_api)
	custom_multiplayer.set_root_node(self)
	custom_multiplayer.set_network_peer(network)
	

func _on_connection_failed():
	print("Failed to connect.")


func _on_connection_succeeded():
	print("Successfully connected.")
	player_id = get_tree().get_network_unique_id()
	rpc_id(1, "fetch_server_time", OS.get_system_time_msecs())
	var latency_timer = Timer.new()
	latency_timer.name = "LatencyTimer"
	latency_timer.wait_time = 0.5
	latency_timer.autostart = true
	latency_timer.connect("timeout", self, "determine_latency")
	self.add_child(latency_timer)


func _physics_process(delta):
	client_clock += int(delta*1000) + delta_latency
	delta_latency = 0
	decimal_collector += (delta * 1000) - int(delta * 1000)
	if decimal_collector >= 1.00: 
		client_clock += 1
		decimal_collector -= 1.00


remote func return_server_time(server_time, client_time):
	latency = (OS.get_system_time_msecs() - client_time) / 2
	client_clock = server_time + latency


func determine_latency():
	rpc_id(1, "determine_latency", OS.get_system_time_msecs())


remote func return_latency(client_time):
	latency_array.append((OS.get_system_time_msecs() - client_time) / 2)
	if latency_array.size() == 9:
		var total_latency = 0
		latency_array.sort()
		var mid_point = latency_array[4]
		for i in range(latency_array.size() - 1, -1, -1):
			if latency_array[i] > (2 * mid_point) and latency_array[i] > 20:
				latency_array.remove(i)
			else:
				total_latency += latency_array[i]
				
		delta_latency = (total_latency / latency_array.size()) - latency
		latency = total_latency / latency_array.size()
#		print("New latency: ", latency)
#		print("Delta latency: ", delta_latency)
		latency_array.clear()
	

func _on_server_disconnected():
	print("SERVER DISCONNECTED!")
	network.poll()
	network.disconnect("connection_failed", self, "_on_connection_failed")
	network.disconnect("connection_succeeded", self, "_on_connection_succeeded")
	network.disconnect("server_disconnected", self, "_on_server_disconnected")
	var latency_timer = get_node("LatencyTimer")
	latency_timer.disconnect("timeout", self, "determine_latency")
	latency_timer.queue_free()
	
	# Try to reconnect if disconnection wasn't requested by the client
	if not should_disconnect:
		reconnect_to_server()


remote func fetch_token():
	print("SERVER: Sending token to server")
	rpc_id(1, "return_token", token, username)
	

remote func return_token_verification_results(result):
	if result:
		if is_instance_valid(login_screen):
			login_screen.queue_free()
		print("Successful token verifcation")
	else:
		print("Login failed, please try again")
		login_screen.login_btn.disabled = false
		login_screen.go_to_signup_btn.disabled = false

