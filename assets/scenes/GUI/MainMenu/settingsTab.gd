@tool
extends VBoxContainer

var booleans:Array[Button]
var strings:Array[Control]

func _ready():
	if Engine.is_editor_hint() and EditorInterface.get_edited_scene_root() is GodotTogetherMainMenu: return
	register_bool($server/enableWhitelist, "server/whitelist_enabled")
	register_bool($server/allowExt, "server/allow_external_connections")
	
	load_settings()

func load_settings():
	for i in strings:
		i.text = GodotTogetherSettings.get_setting(i.get_meta("path"))
	
	for i in booleans:
		i.button_pressed = GodotTogetherSettings.get_setting(i.get_meta("path"))

func register_bool(button:Button, path:String):
	if not button.toggle_mode:
		push_warning(button.name, " is not togglelable")
	
	button.set_meta("path", path)
	button.toggled.connect(func(_val):
		_set_bool(button, path)
	)
	
	booleans.append(button)

func register_text(input: Control, path:String):
	assert(input is LineEdit or input is TextEdit, "Not a LineEdit or TextEdit")
	
	input.set_meta("path", path)
	input.text_changed.connect(_set_text.bind(input, path))
	
	strings.append(input)


func _set_text(input:Control, path:String):
	assert(input is LineEdit or input is TextEdit, "Not a LineEdit or TextEdit")
	GodotTogetherSettings.set_setting(path, input.text)

func _set_bool(button:Button, path:String):
	GodotTogetherSettings.set_setting(path, button.button_pressed)
