@tool
extends EditorPlugin
class_name GodotTogether

signal session_ended

enum Permission {
	EDIT_SCRIPTS,
	EDIT_SCENES,
	DELETE_SCENES,
	DELETE_SCRIPTS,
	ADD_CUSTOM_FILES,
	MODIFY_CUSTOM_FILES
}

const PROTOCOL_VERSION = 1
const SUPPORTED_ENGINE_VERSION = [4, 7, 2]

var client = GDTClient.new(self, "client")
var server = GDTServer.new(self, "server")
var dual = GDTDual.new(self, "dual")

var file_sync = GDTFileSync.new(self, "file_sync")
var node_sync = GDTNodeSync.new(self, "node_sync")

var gui: GodotTogetherGUI = preload("../scenes/GUI/GUI.tscn").instantiate()
var chat: GDTChat = preload("../scenes/GUI/chat/chat.tscn").instantiate()

var button = GDTMenuButton.new()
var toaster: EditorToaster = EditorInterface.get_editor_toaster()

var updater = GDTUpdater.new(self)
var tests = GDTUnitTests.new(self)

var plugin_started := false

var components = [
	client, server, dual,
	file_sync, node_sync, 
	gui,
	updater, 
	tests
]

func _enter_tree() -> void:
	if not pre_start_check():
		printerr("GodotTogether will not run.")
		return
	
	name = "GodotTogether"
	plugin_started = true
	
	var root = get_tree().root
	
	for i in components:
		i.main = self
		root.add_child(i)
	
	setup_menu_button()
	GDTSceneWarning.new(self).add(CONTAINER_CANVAS_EDITOR_MENU)
	GDTSceneWarning.new(self).add(CONTAINER_SPATIAL_EDITOR_MENU)
	
	if not check_path():
		return
	
	if GDTSettings.get_setting("dev/run_tests_on_start"):
		tests.run_tests()
	
	await get_tree().process_frame
	setup_chat()
	
	if GDTSettings.get_setting("update/auto_check_enabled"):
		updater.conditional_check()

func _exit_tree() -> void:
	if not plugin_started:
		return
	
	close_connection()
	button.queue_free()
	remove_control_from_bottom_panel(chat)
	chat.queue_free()
	gui.queue_free()
	queue_free()

func shutdown() -> void:
	EditorInterface.set_plugin_enabled("GodotTogether", false)

func restart() -> void:
	close_connection()

	EditorInterface.get_base_control().add_child(
		GDTRestarter.new()
	)
	
	if not self: return
	if not is_instance_valid(self): return
	
	var tree = get_tree()
	if not tree: return
	
	await tree.create_timer(1).timeout
	gui.alert("Godot is having problems restarting the plugin. Please do it manually")

func is_session_active() -> bool:
	return multiplayer.has_multiplayer_peer() and Engine.is_editor_hint() and (
		GDTUtils.is_peer_connected(client.client_peer) or 
		GDTUtils.is_peer_connected(server.server_peer)
	)

func setup_menu_button() -> void:
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	
	button.get_parent().move_child(button, 1)
	button.pressed.connect(open_menu)

func pre_start_check() -> bool:
	if OS.has_feature("standalone"):
		printerr(
			"GodotTogether ended up in your exported game. \n" +
			"It only wastes space and could slow it down. \n" +
			"Please update your export presets: \n" + 
			"Project -> Export -> <select> -> Resources -> Filters to exclude... -> Add `addons/GodotTogether/*`"
		)

		return false

	return true

func check_path() -> bool:
	var path: String = get_script().get_path()
	
	if path.begins_with("res://addons/GodotTogether/"):
		return true
	
	gui.get_menu_window().set_error_of_death(
		"You didn't install the plugin correctly",
		GDTUtils.join([
			"The plugin's directory must be named 'GodotTogether', not 'GodotTogether-main' or anything else.",
			"Please change it, or the plugin will not work.",
			"",
			"Restart the plugin when you're done.",
			"If you encounter issues, try also restarting Godot."
		], "\n")
	)
	
	return false

func setup_chat() -> void:
	chat.main = self

	var chat_btn = add_control_to_bottom_panel(chat, "Chat")
	chat_btn.tooltip_text = "Toggle GodotTogether chat"

func open_menu() -> void:
	gui.get_menu_window().popup()

func prepare_session() -> void:
	EditorInterface.save_all_scenes()

func close_connection() -> void:
	client.connection_cancelled = true
		
	multiplayer.multiplayer_peer = null

	client.client_peer.close()
	server.server_peer.close()
	
	post_session_end()

func post_session_end() -> void:
	button.reset()
	dual.clear_avatars()

	gui.get_menu().users.clear()
	gui.get_menu().main_menu()

	session_ended.emit()
