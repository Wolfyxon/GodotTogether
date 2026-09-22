@tool
extends VBoxContainer
class_name GDTSettingsErrorGUI

@onready var error_label = $error
@onready var line_label = $line
@onready var path_label = $path

var gui: GodotTogetherGUI

func update() -> void:
	var settings = gui.main.get_settings()
	
	path_label.text = "Path: " + GDTSettings.FILE_PATH
	error_label.text = "Error: %s" % settings.error_message
	line_label.text = "Line: %s" % settings.error_line

func _on_show_file_pressed() -> void:
	OS.shell_show_in_file_manager(GDTSettings.get_absolute_path())

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm(GDTUtils.join([
		"Reset GodotTogether settings to default? Your settings will be lost!",
		"The plugin will restart."
	],"\n")):
		gui.main.get_settings().reset_settings()
		gui.main.restart()

func _on_restart_pressed() -> void:
	if not gui: return
	
	gui.main.restart()
