extends TextureButton

var just_hovered = false
var just_clicked = false
var is_hovered = false

var hover_sound: AudioStreamPlayer
var click_sound: AudioStreamPlayer

export(NodePath) var hover_sound_path
export(NodePath) var click_sound_path

func _ready():
	self.connect("mouse_entered", self, "_on_hover")
	self.connect("mouse_exited", self, "_on_exited")
	self.connect("button_down", self, "on_click")
	self.connect("button_up", self, "on_mouse_up")
	hover_sound = get_node(hover_sound_path)
	click_sound = get_node(click_sound_path)
	
func _process(delta):
#	if just_hovered:
#		get_node("Label").get_font("font").outline_color.a = 1
#		rect_scale = Vector2(1.02, 1.02)
#		if not hover_sound.playing and not is_hovered:
#			hover_sound.play()
#			is_hovered = true
#		if just_hovered:
#			is_hovered = false
#	else:
#		get_node("Label").get_font("font").outline_color.a = 0
#		rect_scale = Vector2(1, 1)
#		just_hovered = false
#		hover_sound.stop()
#
#
#	if just_clicked:
#		if not click_sound.playing:
#			click_sound.play()
#	else:
#		just_clicked = false
#		click_sound.stop()
	
	pass
		
func _on_hover():
	if is_instance_valid(hover_sound):
		hover_sound.play()
	get_node("Label").get_font("font").outline_color.a = 1
	
		
func _on_exited():
	is_hovered = false
	get_node("Label").get_font("font").outline_color.a = 0
	
func on_click():
	if is_instance_valid(click_sound):
		click_sound.play()
	just_clicked = true

func on_mouse_up():
	just_clicked = false
