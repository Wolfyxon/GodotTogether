@tool
extends VBoxContainer
class_name GDTSettingsErrorGUI

@onready var error_label = $error
@onready var line_label = $line
@onready var path_label = $path

var gui: GodotTogetherGUI
var json: JSON

func set_json(new_json: JSON) -> void:
	path_label.text = "Path: " + GDTSettings.FILE_PATH

	if new_json:
		error_label.text = "Error: " + new_json.get_error_message()
		line_label.text = "Line: " + str(new_json.get_error_line())
	else:
		error_label.text = "Failed to access settings"
		line_label.text = ""

	json = new_json

func _on_open_gd_pressed() -> void:
	if not gui: return
	
	var scr = GDScript.new()
	scr.resource_path = GDTSettings.FILE_PATH
	scr.source_code = json.get_parsed_text()

	EditorInterface.edit_script(scr)

func _on_show_file_pressed() -> void:
	OS.shell_show_in_file_manager(GDTSettings.get_absolute_path())

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm(GDTUtils.join([
		"Reset GodotTogether settings to default? Your settings will be lost!",
		"The plugin will restart."
	],"\n")):
		GDTSettings.create_settings()
		gui.main.restart()

func _on_restart_pressed() -> void:
	if not gui: return
	
	gui.main.restart()
