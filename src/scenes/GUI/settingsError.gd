@tool
extends VBoxContainer
class_name GDTSettingsErrorGUI

@onready var error_label = $error
@onready var line_label = $line
@onready var path_label = $path

var gui: GodotTogetherGUI
var json: JSON

func set_json(json: JSON) -> void:
	path_label.text = "Path: " + GDTSettings.FILE_PATH

	if json:
		error_label.text = "Error: " + json.get_error_message()
		line_label.text = "Line: " + str(json.get_error_line())
	else:
		error_label.text = "Failed to access settings"
		line_label.text = ""

	self.json = json

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
	
	if await gui.confirm("Reset GodotTogether settings to default?"):
		GDTSettings.create_settings()
		gui.alert("Settings reset, please restart the plugin.")
