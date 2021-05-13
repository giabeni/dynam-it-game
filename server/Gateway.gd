extends Node

var network = NetworkedMultiplayerENet.new()
var gateway_api = MultiplayerAPI.new()
var ip = "127.0.0.1"
var port = 1910

var username
var password
var create_account

var login_screen

enum CreateAccountResponse {
	FAILED,
	EXISTING,
	WELCOME
}

func _ready():
	pass
	

func _process(delta):
	if get_custom_multiplayer() == null:
		return
	if not custom_multiplayer.has_network_peer():
		return
	custom_multiplayer.poll()


func connect_to_server(_username, _password, _create_account = false):
	network = NetworkedMultiplayerENet.new()
	gateway_api = MultiplayerAPI.new()
	username = _username
	password = _password
	create_account = _create_account
	network.create_client(ip, port)
	set_custom_multiplayer(gateway_api)
	custom_multiplayer.set_root_node(self)
	custom_multiplayer.set_network_peer(network)
	
	network.connect("connection_failed", self, "_on_connection_failed")
	network.connect("connection_succeeded", self, "_on_connection_succeeded")
	

func _on_connection_failed():
	print("Failed to connect to Login Server.")
	login_screen.login_btn.disabled = false
	login_screen.go_to_signup_btn.disabled = false
	login_screen.signup_btn.disabled = false
	login_screen.go_to_login_btn.disabled = false


func _on_connection_succeeded():
	print("Successfully connected to Login Server.")
	if create_account:
		_request_create_account()
	else:
		_request_login()
	

func _request_login():
	print("Connecting to gateway to request login")
	rpc_id(1, "login_request", username, password)
	username = ""
	password = ""
	

remote func return_login_request(results, username, token):
	print("Auth result received: ", results)
	if results == true:
		Server.token = token
		Server.username = username
		Server.connect_to_server()
	else:
		print("Provide corrent username and password")
		login_screen.login_btn.disabled = false
		login_screen.go_to_signup_btn.disabled = false
	
	network.disconnect("connection_failed", self, "_on_connection_failed")
	network.disconnect("connection_succeeded", self, "_on_connection_succeeded")
	

func _request_create_account():
	print("Requesting create account")
	rpc_id(1, "create_account_request", username, password)
	username = ""
	password = ""
	

remote func return_create_account_request(results, message):
	print("Create account results received")
	if results:
		print("Account created, proceed to login")
		login_screen._on_GoToLogin_pressed()
	else:
		if message == CreateAccountResponse.FAILED:
			print("Failed to create account")
		elif message == CreateAccountResponse.EXISTING:
			print("Username already being used")
			
		login_screen.signup_btn.disabled = false
		login_screen.go_to_login_btn.disabled = false
	
	network.disconnect("connection_failed", self, "_on_connection_failed")
	network.disconnect("connection_succeeded", self, "_on_connection_succeeded")
	
	
	
