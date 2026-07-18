@tool
class_name GDTServerSettingsTab
extends VBoxContainer

var gui: GodotTogetherGUI

@onready var password_input = $scroll/vbox/password/value
@onready var password_toggle = $scroll/vbox/password/toggle

func load_settings() -> void:
	password_input.text = GDTSettings.get_setting("server/password")

func set_password_visible(state: bool) -> void:
	password_input.secret = not state
	
	if state:
		password_toggle.icon = GodotTogetherGUI.IMG_VISIBLE
	else:
		password_toggle.icon = GodotTogetherGUI.IMG_HIDDEN

func _on_password_changed(new_text: String) -> void:
	GDTSettings.set_setting("server/password", new_text)
