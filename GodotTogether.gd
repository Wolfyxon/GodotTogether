@tool
extends BetterEditorPlugin_GodotTogether
class_name GodotTogether

const version = "1.0.0"
const compatibility_version = 1

var user_3d_scene = load("res://addons/GodotTogether/assets/scenes/User3D/User3D.tscn")
var user_2d_scene = load("res://addons/GodotTogether/assets/scenes/User2D/User2D.tscn")

var client = GodotTogetherClient.new()
var server = GodotTogetherServer.new()
var dual = GodotTogetherDual.new()

var menu:GodotTogetherMainMenu = load("res://addons/GodotTogether/assets/scenes/GUI/MainMenu/MainMenu.tscn").instantiate()
var button = Button.new()

var user_3d_markers:Array[User3D] = []
var user_2d_markers:Array[User2D] = []

func _enter_tree():
	add_child(client)
	add_child(server)
	add_child(dual)
	
	menu.main = self
	add_child(menu)
	
	menu.visible = false
	button.text = "Godot Together"
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	button.get_parent().move_child(button,button.get_index()-5)
	button.pressed.connect(menu.popup)
	
	create_user_3d(-1)
	pass


func _exit_tree():
	close_connection()
	button.queue_free()

func is_session_active():
	return multiplayer.has_multiplayer_peer() and Engine.is_editor_hint()

func close_connection():
	if not multiplayer.multiplayer_peer: return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	user_2d_markers = []
	user_3d_markers = []

func create_user_3d(id:int, name:="Unknown") -> User3D:
	var usr = user_3d_scene.instantiate()
	usr.main = self
	add_child(usr)
	
	usr.set_username(name)
	usr.id = id
	user_3d_markers.append(usr)
	return usr

func create_user_2d(id:int, name:="Unknown") -> User2D:
	var usr = user_2d_scene.instantiate()
	tree_exiting.connect(usr.queue_free)
	EditorInterface.get_editor_viewport_2d().add_child(usr)
	
	usr.set_username(name)
	usr.id = id
	user_2d_markers.append(usr)
	return usr

func get_user_2d(id:int) -> User2D:
	for i in user_2d_markers:
		if i.id == id and i.is_inside_tree(): 
			return i
	return null 

func get_user_3d(id:int) -> User3D:
	for i in user_3d_markers:
		if i.id == id and i.is_inside_tree(): 
			return i
	return null 
