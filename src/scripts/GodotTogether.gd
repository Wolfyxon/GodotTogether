@tool
extends EditorPlugin
class_name GodotTogether

enum Permission {
	EDIT_SCRIPTS,
	EDIT_SCENES,
	DELETE_SCENES,
	DELETE_SCRIPTS,
	ADD_CUSTOM_FILES,
	MODIFY_CUSTOM_FILES
}

const VERSION = "1.0.0"
const PROTOCOL_VERSION = 1

var client = GDTClient.new(self, "client")
var server = GDTServer.new(self, "server")
var dual = GDTDual.new(self, "dual")
var change_detector = GDTChangeDetector.new(self, "changeDetector")

var gui: GodotTogetherGUI = preload("res://addons/GodotTogether/src/scenes/GUI/GUI.tscn").instantiate()
var button = GDTMenuButton.new()
var toaster: EditorToaster = EditorInterface.get_editor_toaster()

func _enter_tree() -> void:
	name = "GodotTogether"

	add_child(change_detector)
	add_child(client)
	add_child(server)
	add_child(dual)
	
	gui.main = self
	add_child(gui)
	
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	
	button.get_parent().move_child(button, 1)
	button.pressed.connect(gui.get_menu_window().popup)
	

func _exit_tree() -> void:
	close_connection()
	button.queue_free()
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
