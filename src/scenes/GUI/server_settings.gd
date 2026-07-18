@tool
class_name GDTServerSettingsTab
extends VBoxContainer

@onready var password_toggle = $scroll/vbox/password/toggle

func set_password_visible(state: bool) -> void:
	$scroll/vbox/password/value.secret = not state
	
	if state:
		password_toggle.icon = GodotTogetherGUI.IMG_VISIBLE
	else:
		password_toggle.icon = GodotTogetherGUI.IMG_HIDDEN
	
