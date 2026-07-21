@tool
extends PopupPanel
class_name GDTSettingsGUI

@onready var vbox = $main/scroll/vbox
@onready var update_check_btn = $main/scroll/vbox/updateCheckTimeHbox/btnCheckUpdateNow

var gui: GodotTogetherGUI
var controls: Array[Control] = []

func _ready() -> void:
	await get_tree().process_frame
	
	if not gui: return
	if not gui.visuals_available(): return
	
	for i in GDTUtils.get_descendants(vbox):
		if i.has_meta("setting"):
			register_control(i)

func register_control(node: Control) -> void:
	var path = node.get_meta("setting")
	controls.append(node)
	
	GDTSettings.make_setting_control(node, path)

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm(GDTUtils.join([
		"Do you want to reset the plugin to the default state?",
		"All your settings will be lost.",
		"",
		"The plugin will restart."
	], "\n")):
		GDTSettings.create_settings()
		gui.get_menu_window().hide()  # For some reason it resets to the default state and doesn't hide after a reset
		
		if gui.main:
			gui.main.restart()

func _on_show_file_pressed() -> void:
	OS.shell_show_in_file_manager(GDTSettings.get_absolute_path())

func _on_shutdown_pressed() -> void:
	if await gui.confirm("Are you sure you want to shut down and disable the plugin?"):
		gui.main.shutdown()

func _on_restart_pressed() -> void:
	if await gui.confirm("Are you sure you want to restart the plugin?"):
		gui.main.restart()

func _on_btn_check_update_now_pressed() -> void:
	if not gui: return
	update_check_btn.disabled = true
	
	gui.main.updater.apply_update()
	return
	
	var res = await gui.main.updater.check()
	update_check_btn.disabled = false
	
	if not res:
		gui.alert("Unknown error. Update checker did not respond.", "Unable to check for updates")
		return
	
	if res.type == GDTUpdateCheckResult.ResultType.RunningLatest:
		gui.alert("No new updates detected")
		return
	
	if res.type == GDTUpdateCheckResult.ResultType.Fail:
		gui.alert(res.error, "Error while checking for updates")
		return
	
	if await gui.confirm("New version available: '%s'! Update now?" % res.version):
		gui.main.updater.begin_update(res)
	
