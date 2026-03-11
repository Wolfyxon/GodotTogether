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

var client = GDTClient.new(self, "client")
var server = GDTServer.new(self, "server")
var dual = GDTDual.new(self, "dual")
var change_detector = GDTChangeDetector.new(self, "changeDetector")

var gui: GodotTogetherGUI = preload("res://addons/GodotTogether/src/scenes/GUI/GUI.tscn").instantiate()
var chat: GDTChat = preload("res://addons/GodotTogether/src/scenes/GUI/chat/chat.tscn").instantiate()

var button = GDTMenuButton.new()
var toaster: EditorToaster = EditorInterface.get_editor_toaster()

var plugin_started := false
var components = [
	client, server, dual, change_detector, gui
]

func _enter_tree() -> void:	
	if not pre_start_check():
		printerr("GodotTogether will not run.")
		return

	plugin_started = true

	name = "GodotTogether"
	gui.main = self

	var root = get_tree().root
	
	for i in components:
		root.add_child(i)
	
	setup_menu_button()
	GDTSceneWarning.new(self).add(CONTAINER_CANVAS_EDITOR_MENU)
	GDTSceneWarning.new(self).add(CONTAINER_SPATIAL_EDITOR_MENU)
	
	await get_tree().process_frame
	setup_chat()

func _exit_tree() -> void:
	if not plugin_started:
		return
	
	close_connection()
	button.queue_free()
	remove_control_from_bottom_panel(chat)
	chat.queue_free()
	gui.queue_free()
	queue_free()

func restart() -> void:
	close_connection()

	EditorInterface.get_base_control().add_child(
		GDTRestarter.new()
	)

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
