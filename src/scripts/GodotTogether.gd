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

const version = "1.0.0"
const protocol_version = 1

var client = GodotTogetherClient.new(self, "client")
var server = GodotTogetherServer.new(self, "server")
var dual = GodotTogetherDual.new(self, "dual")
var change_detector = GodotTogetherChangeDetector.new(self, "changeDetector")

var menu: GodotTogetherMainMenu = load("res://addons/GodotTogether/src/scenes/GUI/MainMenu/MainMenu.tscn").instantiate()
var button = Button.new()

func _enter_tree():
	name = "GodotTogether"

	add_child(change_detector)
	add_child(client)
	add_child(server)
	add_child(dual)
	
	menu.main = self
	add_child(menu)
	
	menu.visible = false
	button.text = "Godot Together"
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	button.get_parent().move_child(button, button.get_index() - 5)
	button.pressed.connect(menu.popup)
	

func _exit_tree():
	close_connection()
	button.queue_free()

func is_session_active():
	return multiplayer.has_multiplayer_peer() and Engine.is_editor_hint() and (
		GodotTogetherUtils.is_peer_connected(client.client_peer) or 
		GodotTogetherUtils.is_peer_connected(server.server_peer)
	)

func close_connection():
	if not multiplayer.multiplayer_peer: return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	dual.avatar_2d_markers.clear()
	dual.avatar_3d_markers.clear()
