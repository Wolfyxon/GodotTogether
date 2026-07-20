@tool
extends PopupPanel
class_name GDTSettingsGUI

@onready var vbox = $main/scroll/vbox

var gui: GodotTogetherGUI
var controls: Array[Control] = []

func _ready() -> void:
	await get_tree().process_frame
	
	if not gui: return
	if not gui.visuals_available(): return
	
	# Use GDTUtils.get_descendants() if the controls get nested
	for i in vbox.get_children():
		if i.has_meta("setting"):
			register_control(i)

func register_control(node: Control) -> void:
	var path = node.get_meta("setting")
	controls.append(node)
	
	GDTSettings.make_setting_control(node, path)

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm(GDTUtils.join([
		"Do you want to reset the plugin to the default state?",
		"All your settings will be lost.",
		"",
		"The plugin will restart."
	], "\n")):
		GDTSettings.create_settings()
		gui.get_menu_window().hide()  # For some reason it resets to the default state and doesn't hide after a reset
		
		if gui.main:
			gui.main.restart()

func _on_show_file_pressed() -> void:
	OS.shell_show_in_file_manager(GDTSettings.get_absolute_path())

func _on_shutdown_pressed() -> void:
	if await gui.confirm("Are you sure you want to shut down and disable the plugin?"):
		EditorInterface.set_plugin_enabled("GodotTogether", false)

func _on_restart_pressed() -> void:
	if await gui.confirm("Are you sure you want to restart the plugin?"):
		gui.main.restart()
