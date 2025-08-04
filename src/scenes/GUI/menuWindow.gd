@tool
extends PopupPanel
class_name GDTMenuWindow

var main: GodotTogether
var gui: GodotTogetherGUI

func _ready() -> void:
	await get_tree().physics_frame
	
	if main:
		$about/scroll/vbox/version.text = "Version: " + main.get_plugin_version()

	if gui.visuals_available():
		var settings_json = GDTSettings.get_settings_json()
		var error_gui = get_settings_error_gui()
		var settings_gui = get_settings_gui()

		settings_gui.visible = false

		if settings_json and settings_json.get_error_line() == 0:
			error_gui.visible = false
			
			var seen_disclaimer = GDTSettings.get_setting("seen/disclaimer")
			get_menu().visible = seen_disclaimer
			get_disclaimer().visible = not seen_disclaimer
			
			settings_gui.gui = gui
		else:
			error_gui.gui = gui
			error_gui.set_json(settings_json)
			error_gui.visible = true

func get_settings_gui() -> GDTSettingsGUI:
	return $settings

func get_menu() -> GDTMenu:
	return $main

func get_disclaimer() -> GDTDisclaimer:
	return $disclaimer

func get_settings_error_gui() -> GDTSettingsErrorGUI:
	return $settingsError
