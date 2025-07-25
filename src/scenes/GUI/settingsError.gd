@tool
extends VBoxContainer
class_name GDTSettingsErrorGUI

@onready var error_label = $error
@onready var line_label = $line

var gui: GodotTogetherGUI

func set_json(json: JSON) -> void:
	error_label.text = "Error: " + json.get_error_message()
	line_label.text = "Line: " + str(json.get_error_line())
	

func _on_open_gd_pressed() -> void:
	if not gui: return
	
	EditorInterface.edit_script(load(GDTSettings.FILE_PATH))

func _on_open_ext_pressed() -> void:
	pass # Replace with function body.

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm("Reset GodotTogether settings to default?"):
		GDTSettings.create_settings()
