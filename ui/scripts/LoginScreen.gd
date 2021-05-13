extends Control

onready var login_box: VBoxContainer = $CenterContainer/LoginBox
onready var username_input: LineEdit = $CenterContainer/LoginBox/Username
onready var password_input: LineEdit = $CenterContainer/LoginBox/Password
onready var login_btn: TextureButton = $CenterContainer/LoginBox/LoginButton
onready var go_to_signup_btn: TextureButton = $CenterContainer/LoginBox/GoToSignup

onready var signup_box: VBoxContainer = $CenterContainer/SignupBox
#onready var email_input: LineEdit = $CenterContainer/SignupBox/Email
onready var new_username_input: LineEdit = $CenterContainer/SignupBox/Username
onready var new_password_input: LineEdit = $CenterContainer/SignupBox/Password
onready var confirm_password_input: LineEdit = $CenterContainer/SignupBox/ConfirmPassword
onready var signup_btn: TextureButton = $CenterContainer/SignupBox/SignupButton
onready var go_to_login_btn: TextureButton = $CenterContainer/SignupBox/GoToLogin


func _ready():
	Gateway.login_screen = self
	Server.login_screen = self


func _on_LoginButton_pressed():
	if username_input.text.length() <= 0 or password_input.text.length() <= 0:
		print("Please, provide username and password")
	else:
		login_btn.disabled = true
		go_to_signup_btn.disabled = true
		var username = username_input.text
		var password = password_input.text
		print("Logging in...")
		Gateway.connect_to_server(username, password, false)


func _on_SignupButton_pressed():
	if new_username_input.text.length() <= 0 or new_password_input.text.length() <= 0 or confirm_password_input.text.length() <= 0:
		print("Please, provide all fields")
	elif confirm_password_input.text != new_password_input.text:
		print("Verify your password")
	else:
		signup_btn.disabled = true
		go_to_login_btn.disabled = true
		var username = new_username_input.text
		var password = new_password_input.text
		print("Logging in...")
		Gateway.connect_to_server(username, password, true)


func _on_GoToSignup_pressed():
	signup_btn.disabled = false
	go_to_login_btn.disabled = false
	login_box.hide()
	signup_box.show()


func _on_GoToLogin_pressed():
	login_btn.disabled = false
	go_to_signup_btn.disabled = false
	signup_box.hide()
	login_box.show()
