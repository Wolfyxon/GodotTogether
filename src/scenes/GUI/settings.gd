@tool
extends PopupPanel
class_name GDTSettingsGUI

var gui: GodotTogetherGUI

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm(GDTUtils.join([
		"Do you want to reset the plugin to the default state?",
		"All your settings will be lost.",
		"",
		"The plugin will turn off and you'll need to reenable it manually."
	], "\n")):
		GDTSettings.write_settings(GDTSettings.default_data)
		EditorInterface.set_plugin_enabled("GodotTogether", false)
