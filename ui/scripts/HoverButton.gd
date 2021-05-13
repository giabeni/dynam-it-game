extends TextureButton

var just_hovered = false
var just_clicked = false
var is_hovered = false

func _ready():
	self.connect("mouse_entered", self, "_on_hover")
	self.connect("mouse_exited", self, "_on_exited")
	self.connect("button_down", self, "on_click")
	self.connect("button_up", self, "on_mouse_up")
	
func _process(delta):
	
	pass
		
func _on_hover():
	Sounds.play_hover_sound()
	get_node("Label").get_font("font").outline_color.a = 1
	
		
func _on_exited():
	is_hovered = false
	get_node("Label").get_font("font").outline_color.a = 0
	
func on_click():
	Sounds.play_click_sound()
	just_clicked = true

func on_mouse_up():
	just_clicked = false
