@tool
extends PopupPanel
class_name GDTMenuWindow

var main: GodotTogether
var gui: GodotTogetherGUI

func _ready() -> void:
	await get_tree().physics_frame
	
	if gui.visuals_available():
		$about/scroll/vbox/version.text = "Version: " + GodotTogether.VERSION
		
		var settings_json = GDTSettings.get_settings_json()
		
		if settings_json.get_error_line() == 0:
			$settingsError.visible = false
			
			var seen_disclaimer = GDTSettings.get_setting("seen/disclaimer")
			get_menu().visible = seen_disclaimer
			get_disclaimer().visible = not seen_disclaimer
		else:
			$settingsError.set_json(settings_json)
			$settingsError.visible = true

func get_menu() -> GDTMenu:
	return $main

func get_disclaimer() -> GDTDisclaimer:
	return $disclaimer
