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

var client = GodotTogetherClient.new(self, "client")
var server = GodotTogetherServer.new(self, "server")
var dual = GodotTogetherDual.new(self, "dual")
var change_detector = GodotTogetherChangeDetector.new(self, "changeDetector")

#var menu: GodotTogetherMainMenu = load("res://addons/GodotTogether/src/scenes/GUI/MainMenu/MainMenu.tscn").instantiate()
var gui: GodotTogetherGUI = preload("res://addons/GodotTogether/src/scenes/GUI/GUI.tscn").instantiate()
var button = Button.new()

func _enter_tree():
	name = "GodotTogether"

	add_child(change_detector)
	add_child(client)
	add_child(server)
	add_child(dual)
	
	gui.main = self
	add_child(gui)
	
	button.text = "Godot Together"
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	
	button.get_parent().move_child(button, 1)
	button.pressed.connect(gui.get_menu_window().popup)
	

func _exit_tree():
	close_connection()
	button.queue_free()
	# ImmortalOctogen: To prevent from endless executing unfreed scripts + nodes
	queue_free()

func is_session_active():
	return multiplayer.has_multiplayer_peer() and Engine.is_editor_hint() and (
		GodotTogetherUtils.is_peer_connected(client.client_peer) or 
		GodotTogetherUtils.is_peer_connected(server.server_peer)
	)

func prepare_session():
	EditorInterface.save_all_scenes()

func close_connection():
	if not multiplayer.multiplayer_peer: return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	dual.clear_avatars()
