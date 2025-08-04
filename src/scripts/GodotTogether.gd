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

var components = [
	client, server, dual, change_detector, gui
]

func _enter_tree() -> void:
	var root = get_tree().root
	
	name = "GodotTogether"
	gui.main = self

	for i in components:
		root.add_child(i)
		print(i.get_path())
	
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	
	button.get_parent().move_child(button, 1)
	button.pressed.connect(gui.get_menu_window().popup)
	
	await get_tree().process_frame

	chat.main = self
	var chat_btn = add_control_to_bottom_panel(chat, "Chat")
	chat_btn.tooltip_text = "Toggle GodotTogether chat"

func _exit_tree() -> void:
	close_connection()
	button.queue_free()
	remove_control_from_bottom_panel(chat)
	chat.queue_free()
	queue_free()

func is_session_active() -> bool:
	return multiplayer.has_multiplayer_peer() and Engine.is_editor_hint() and (
		GDTUtils.is_peer_connected(client.client_peer) or 
		GDTUtils.is_peer_connected(server.server_peer)
	)

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

	session_ended.emit()
