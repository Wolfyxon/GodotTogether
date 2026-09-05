@tool
extends PopupPanel
class_name GDTMenuWindow

var main: GodotTogether
var gui: GodotTogetherGUI

var triggered_reflows := 0

func _ready() -> void:
	await get_tree().physics_frame
	
	if main:
		$about/main/scroll/vbox/version.text = "Version: " + main.get_plugin_version()

	if gui.visuals_available():
		var settings_json = GDTSettings.get_settings_json()
		var error_gui = get_settings_error_gui()
		var settings_gui = get_settings_gui()
		var menu = get_menu()
		
		get_error_gui().visible = false
		settings_gui.visible = false

		if not GDTSettings.settings_exist() or (settings_json and settings_json.get_error_line() == 0):
			error_gui.visible = false
			
			var seen_disclaimer = GDTSettings.get_setting("seen/disclaimer")
			menu.visible = seen_disclaimer
			get_disclaimer().visible = not seen_disclaimer
			
			settings_gui.gui = gui
		else:
			menu.visible = false
			error_gui.gui = gui
			error_gui.set_json(settings_json)
			error_gui.visible = true

func checked_reflow() -> void:
	if triggered_reflows < 3:
		reflow()

# Sometimes using expanding controls causes the UI to overflow
# Resizing the window fixes that
func reflow() -> void:
	triggered_reflows += 1
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	position += Vector2i(1, 1)
	size += Vector2i(1, 1)

func hide_all_guis() -> void:
	for i in get_children():
		if i is Control:
			i.visible = false

func set_error_of_death(title: String, description: String) -> void:
	triggered_reflows = 0
	
	if not is_node_ready():
		await ready
	
	await get_tree().process_frame
	hide_all_guis()
	
	await get_tree().process_frame
	hide_all_guis()
	
	$error.show()
	$error/header.text = title
	$error/description.text = description

func get_settings_gui() -> GDTSettingsGUI:
	return $settings

func get_menu() -> GDTMenu:
	return $main

func get_disclaimer() -> GDTDisclaimer:
	return $disclaimer

func get_settings_error_gui() -> GDTSettingsErrorGUI:
	return $settingsError

func get_error_gui() -> Control:
	return $error

func _on_btn_restart_pressed() -> void:
	main.restart()
