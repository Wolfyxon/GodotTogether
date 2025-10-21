@tool
extends PopupPanel
class_name GDTSettingsGUI

@onready var vbox = $main/scroll/vbox

var gui: GodotTogetherGUI
var controls: Array[Control] = []

func _ready() -> void:
	await get_tree().process_frame
	
	# Use GDTUtils.get_descendants() if the controls are nested
	for i in vbox.get_children():
		if i.has_meta("setting"):
			register_control(i)

func register_control(node: Control) -> void:
	var path = node.get_meta("setting")
	controls.append(node)
	
	if node is Button:
		node.toggled.connect(set_setting.bind(path))
	else:
		push_error("Unsupported control %s %s" % [node.get_class(), get_path_to(node)])
		return
	
	update_control(node)

func update_control(node: Control) -> void:
	var path = node.get_meta("setting")
	var value = GDTSettings.get_setting(path)
	
	if node is Button:
		node.button_pressed = value

func set_setting(value, path: String) -> void:
	GDTSettings.set_setting(path, value)

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm(GDTUtils.join([
		"Do you want to reset the plugin to the default state?",
		"All your settings will be lost.",
		"",
		"The plugin will turn off and you'll need to reenable it manually."
	], "\n")):

		GDTSettings.write_settings(GDTSettings.DEFAULT_DATA)
		gui.get_menu_window().hide() # For some reason it resets to the default state and doesn't hide after a reset
		
		EditorInterface.set_plugin_enabled("GodotTogether", false)

func _on_show_file_pressed() -> void:
	OS.shell_show_in_file_manager(GDTSettings.get_absolute_path())
