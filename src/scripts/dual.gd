extends Node
## Class for managing session logic that runs on both server and client
class_name GodotTogetherDual

var main: GodotTogether
var camera: Camera3D
var update_timer = Timer.new()

var prev_mouse_pos := Vector2()
var prev_3d_pos := Vector3()
var prev_3d_rot := Vector3()

var user_3d_scene = load("res://addons/GodotTogether/src/scenes/User3D/User3D.tscn")
var user_2d_scene = load("res://addons/GodotTogether/src/scenes/User2D/User2D.tscn")

var user_3d_markers: Array[User3D] = []
var user_2d_markers: Array[User2D] = []

func _ready():
	if not main: return
	camera = main.get_editor_interface().get_editor_viewport_3d().get_camera_3d()
	
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)
	
	main.change_detector.scene_changed.connect(_scene_changed)
	main.change_detector.node_properties_changed.connect(_node_properties_changed)
	
	update_timer.timeout.connect(_update)
	update_timer.one_shot = false
	update_timer.wait_time = 0.02
	add_child(update_timer)
	update_timer.start()

func _update():
	if not main: return
	if not main.is_session_active(): return
	
	var mPos = EditorInterface.get_editor_viewport_2d().get_mouse_position() / Vector2(EditorInterface.get_editor_viewport_2d().size)
	if mPos != prev_mouse_pos and DisplayServer.window_is_focused():
		prev_mouse_pos = mPos
		update_2d_marker.rpc(mPos)
		
	if camera.position != prev_3d_pos or camera.rotation != prev_3d_rot:
		prev_3d_pos = camera.position
		prev_3d_rot = camera.rotation
		
		update_3d_marker.rpc(camera.position, camera.rotation)

func _connected(id: int):
	pass
	
func _disconnected(id: int):
	var marker3d = get_user_3d(id)
	var marker2d = get_user_2d(id)
	
	if marker2d: 
		marker2d.queue_free()
		main.user_2d_markers.erase(marker2d)
	if marker3d: 
		marker3d.queue_free()
		main.user_3d_markers.erase(marker3d)
	

func _scene_changed():
	var scene = main.get_editor_interface().get_edited_scene_root()
	if not scene: return
	
	main.change_detector.observe_recursive(scene)

func _node_properties_changed(node: Node, changed_keys: Array):
	if not main: return
	if not main.is_session_active(): return
	
	if not is_instance_valid(node): return
	
	var scene = main.get_editor_interface().get_edited_scene_root()
	if not scene: return
	
	var scene_path = scene.scene_file_path
	var node_path = scene.get_path_to(node)
	var dict = {}
	
	for key in changed_keys:
		dict[key] = node[key]
	
	if main.client.is_active():
		main.server.node_update_request.rpc_id(0, scene_path, node_path, dict)
	elif main.server.is_active():
		main.server.submit_node_update(scene_path, node_path, dict)

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


@rpc("any_peer")
func update_2d_marker(vector: Vector2):
	if not main: return
	var marker = get_user_2d(multiplayer.get_remote_sender_id())
	if not marker: return
	marker.set_position_percent(vector)

@rpc("any_peer")
func update_3d_marker(position: Vector3, rotation: Vector3):
	if not main: return
	var marker = get_user_3d(multiplayer.get_remote_sender_id())
	if not marker: return
	marker.position = position
	marker.rotation = rotation
