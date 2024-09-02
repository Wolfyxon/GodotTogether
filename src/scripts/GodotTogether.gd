@tool
extends EditorPlugin
class_name GodotTogether

const version = "1.0.0"
const compatibility_version = 1

var client = GodotTogetherClient.new()
var server = GodotTogetherServer.new()
var dual = GodotTogetherDual.new()
var change_detector = GodotTogetherChangeDetector.new()

var menu: GodotTogetherMainMenu = load("res://addons/GodotTogether/src/scenes/GUI/MainMenu/MainMenu.tscn").instantiate()
var button = Button.new()

func _enter_tree():
	name = "GodotTogether"
	
	change_detector.main = self
	change_detector.name = "change_detector"
	add_child(change_detector)
	
	client.main = self
	client.name = "client"
	add_child(client)
	
	server.main = self
	server.name = "server"
	add_child(server)
	
	dual.main = self
	dual.name = "dual"
	add_child(dual)
	
	menu.main = self
	add_child(menu)
	
	menu.visible = false
	button.text = "Godot Together"
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	button.get_parent().move_child(button,button.get_index() - 5)
	button.pressed.connect(menu.popup)
	

func _exit_tree():
	close_connection()
	button.queue_free()

func is_session_active():
	return multiplayer.has_multiplayer_peer() and Engine.is_editor_hint() and (
		GodotTogetherUtils.is_peer_connected(client) or 
		GodotTogetherUtils.is_peer_connected(server)
	)

func close_connection():
	if not multiplayer.multiplayer_peer: return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	dual.user_2d_markers.clear()
	dual.user_3d_markers.clear()
