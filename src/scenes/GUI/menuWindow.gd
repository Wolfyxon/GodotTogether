@tool
extends PopupPanel
class_name GDTMenuWindow

var main: GodotTogether
var gui: GodotTogetherGUI

func _ready() -> void:
	await get_tree().physics_frame
	
	if gui.visuals_available():
		$about/scroll/vbox/version.text = "Version: " + GodotTogether.VERSION
		
		var seen_disclaimer = GDTSettings.get_setting("seen/disclaimer")
		get_menu().visible = seen_disclaimer
		get_disclaimer().visible = not seen_disclaimer

func get_menu() -> GDTMenu:
	return $main

func get_disclaimer() -> GDTDisclaimer:
	return $disclaimer
