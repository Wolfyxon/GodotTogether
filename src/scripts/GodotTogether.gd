@tool
extends BetterEditorPlugin_GodotTogether
class_name GodotTogether

const version = "1.0.0"
const compatibility_version = 1
const ignored_dirs = [".godot", ".import", ".vscode", "addons"]

var user_3d_scene = load("res://addons/GodotTogether/src/scenes/User3D/User3D.tscn")
var user_2d_scene = load("res://addons/GodotTogether/src/scenes/User2D/User2D.tscn")

var client = GodotTogetherClient.new()
var server = GodotTogetherServer.new()
var dual = GodotTogetherDual.new()
var change_detector = GodotTogetherChangeDetector.new()

var menu: GodotTogetherMainMenu = load("res://addons/GodotTogether/src/scenes/GUI/MainMenu/MainMenu.tscn").instantiate()
var button = Button.new()

var user_3d_markers: Array[User3D] = []
var user_2d_markers: Array[User2D] = []

func _enter_tree():
	name = "GodotTogether"

	client.main = self
	client.name = "client"
	add_child(client)
	
	server.main = self
	server.name = "server"
	add_child(server)
	
	dual.main = self
	dual.name = "dual"
	add_child(dual)
	
	change_detector.main = self
	change_detector.name = "change_detector"
	add_child(change_detector)
	
	menu.main = self
	add_child(menu)
	
	
	menu.visible = false
	button.text = "Godot Together"
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, button)
	button.get_parent().move_child(button,button.get_index()-5)
	button.pressed.connect(menu.popup)
	

func _exit_tree():
	close_connection()
	button.queue_free()

func get_files(path: String) -> Array[String]:
	var res: Array[String] = []
	
	var dir = DirAccess.open(path)
	assert(dir, "Failed to open " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if !dir.current_is_dir():
			res.append(file_name)
		
		file_name = dir.get_next()
		
	return res

func get_dirs(path: String) -> Array[String]:
	var res: Array[String] = []
	
	var dir = DirAccess.open(path)
	assert(dir, "Failed to open " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			res.append(file_name)
		
		file_name = dir.get_next()
		
	return res

func get_fs_hash(path := "res://") -> int:
	var res = 0
	
	var dir = DirAccess.open(path)
	assert(dir, "Failed to open " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		res += file_name.hash()
		
		if dir.current_is_dir():
			res += get_fs_hash(path + "/" + file_name)
		else:
			var f = FileAccess.open(path + "/" + file_name, FileAccess.READ)
			res += hash(f.get_buffer(f.get_length()))
			f.close()
		
		file_name = dir.get_next()
	
	return res

func is_session_active():
	return multiplayer.has_multiplayer_peer() and Engine.is_editor_hint() and (
		client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED or 
		server.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	)

func close_connection():
	if not multiplayer.multiplayer_peer: return
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	
	user_2d_markers = []
	user_3d_markers = []

@rpc("authority", "call_remote", "reliable")
func create_user_3d(id: int, name := "Unknown") -> User3D:
	var usr = user_3d_scene.instantiate()
	usr.main = self
	add_child(usr)
	
	usr.set_username(name)
	usr.id = id
	user_3d_markers.append(usr)
	return usr

@rpc("authority", "call_remote", "reliable")
func create_user_2d(id: int, name := "Unknown") -> User2D:
	var usr = user_2d_scene.instantiate()
	tree_exiting.connect(usr.queue_free)
	EditorInterface.get_editor_viewport_2d().add_child(usr)
	
	usr.set_username(name)
	usr.id = id
	user_2d_markers.append(usr)
	return usr

func get_user_2d(id: int) -> User2D:
	for i in user_2d_markers:
		if i.id == id and i.is_inside_tree(): 
			return i
	return null 

func get_user_3d(id: int) -> User3D:
	for i in user_3d_markers:
		if i.id == id and i.is_inside_tree(): 
			return i
	return null 
