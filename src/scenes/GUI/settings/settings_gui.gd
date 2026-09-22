@tool
extends PopupPanel
class_name GDTSettingsGUI

signal settings_changed

const WARNING_IMG = preload("../../../img/warning.svg")

@onready var vbox = $main/scroll/vbox
@onready var update_check_btn = $main/scroll/vbox/updateCheckTimeHbox/btnCheckUpdateNow
@onready var sandwich_title: Label = $main/scroll/vbox/sandwichTitle

var gui: GodotTogetherGUI
var controls: Array[Control] = []

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not gui: return
	if not gui.visuals_available(): return
	
	for i in GDTUtils.get_descendants(vbox):
		if i.has_meta("setting"):
			register_control(i)
	
	$DevMenu.main = gui.main
	$main/scroll/vbox/devActions/btnRunTests.pressed.connect(gui.main.tests.run_tests)
	hide()
	
	sandwich_title.hide()
	_settings_changed()

func _settings_changed() -> void:
	settings_changed.emit()

func open_dev_menu() -> void:
	visible = true
	$DevMenu.popup()

func register_control(node: Control) -> void:
	var path = node.get_meta("setting")
	controls.append(node)
	
	var format = ""
	
	if node.has_meta("warn_when"):
		setup_control_with_warning(node)
	
	if node.has_meta("format"):
		format = node.get_meta("format")
	
	if node.has_meta("disabled_by_node"):
		var disabler = node.get_node(node.get_meta("disabled_by_node"))
		setup_control_with_node_disabler(node, disabler)
	
	if node.has_meta("enabled_by_node"):
		var enabler = node.get_node(node.get_meta("enabled_by_node"))
		setup_control_with_node_disabler(node, enabler, true)
	
	gui.main.get_settings().make_setting_control(node, path, format, _settings_changed)

func setup_control_with_warning(node: Control) -> void:
	if not node is Button:
		printerr("Not not supported for warn_when: %s" % node)
		return
	
	var warn_state = node.get_meta("warn_when")
	
	var update = func():
		if warn_state == node.button_pressed:
			node.icon = WARNING_IMG
		else:
			node.icon = null
	
	node.pressed.connect(update)
	update.call_deferred()

func setup_control_with_node_disabler(node: Control, disabler: Control, reverse = false) -> void:
	if not disabler:
		printerr("Disabler is null for node %s" % node)
		return
	
	if not disabler is Button:
		printerr("%s must be a button to work as a disabler for %s" % [disabler, node])
		return
	
	var update = func():
		if reverse:
			GDTUtils.set_control_disabled(node, not disabler.button_pressed)
		else:
			GDTUtils.set_control_disabled(node, disabler.button_pressed)
	
	disabler.pressed.connect(update)
	update.call()

func _on_reset_pressed() -> void:
	if not gui: return
	
	if await gui.confirm(GDTUtils.join([
		"Do you want to reset the plugin to the default state?",
		"All your settings will be lost.",
		"",
		"The plugin will restart."
	], "\n")):
		gui.main.get_settings().reset_settings()
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
	
	var res = await gui.main.updater.check()
	update_check_btn.disabled = false
	
	if not res:
		gui.alert("Unknown error. Update checker did not respond.", "Unable to check for updates")
		return
	
	if res.type == GDTUpdateCheckResult.ResultType.RunningLatest:
		gui.alert(
			GDTUtils.join([
				"Official stable version not yet released!",
				"You will get notified here if it arrives.",
				"",
				"Check GitHub for the latest source code."
			], "\n")
		)
		return
	
	if res.type == GDTUpdateCheckResult.ResultType.Fail:
		gui.alert(res.error, "Error while checking for updates")
		return
	
	if await gui.confirm("New version available: '%s'! Update now?" % res.version):
		gui.main.updater.begin_update(res)


func _on_sandwich_btn_pressed() -> void:
	sandwich_title.show()
