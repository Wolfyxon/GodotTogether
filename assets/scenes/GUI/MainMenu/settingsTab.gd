@tool
extends VBoxContainer

func _ready():
	pass


func register_bool(button:Button, path:String):
	if not button.toggle_mode:
		push_warning(button.name, " is not togglelable")
	
	button.toggled.connect(_set_bool.bind(button, path))

func register_text(input: Control, path:String):
	assert(input is LineEdit or input is TextEdit, "Not a LineEdit or TextEdit")
	input.text_changed.connect(_set_text.bind(input, path))


func _set_text(input:Control, path:String):
	assert(input is LineEdit or input is TextEdit, "Not a LineEdit or TextEdit")
	GodotTogetherSettings.set_setting(path, input.text)

func _set_bool(button:Button, path:String):
	GodotTogetherSettings.set_setting(path, button.button_pressed)
