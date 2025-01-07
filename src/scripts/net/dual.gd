extends GodotTogetherComponent
## Class for managing session logic that runs on both server and client
class_name GodotTogetherDual

var camera: Camera3D
var update_timer = Timer.new()

var prev_mouse_pos := Vector2()
var prev_3d_pos := Vector3()
var prev_3d_rot := Vector3()

var avatar_3d_scene = load("res://addons/GodotTogether/src/scenes/Avatar3D/Avatar3D.tscn")
var avatar_2d_scene = load("res://addons/GodotTogether/src/scenes/Avatar2D/Avatar2D.tscn")

var avatar_3d_markers: Array[GodotTogetherAvatar3D] = []
var avatar_2d_markers: Array[GodotTogetherAvatar2D] = []

func _ready():
	if not main: return
	camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)
	
	main.change_detector.scene_changed.connect(_scene_changed)
	main.change_detector.node_properties_changed.connect(_node_properties_changed)
	main.change_detector.node_removed.connect(_node_removed)
	main.change_detector.node_added.connect(_node_added)
	
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
		update_2d_avatar.rpc(mPos)
		
	if camera.position != prev_3d_pos or camera.rotation != prev_3d_rot:
		prev_3d_pos = camera.position
		prev_3d_rot = camera.rotation
		
		update_3d_avatar.rpc(camera.position, camera.rotation)

func _connected(id: int):
	pass
	
func _disconnected(id: int):
	var marker3d = get_avatar_3d(id)
	var marker2d = get_avatar_2d(id)
	
	if marker2d: 
		marker2d.queue_free()
		avatar_2d_markers.erase(marker2d)
	if marker3d: 
		marker3d.queue_free()
		avatar_3d_markers.erase(marker3d)

func _scene_changed():
	var scene = EditorInterface.get_edited_scene_root()
	if not scene: return
	
	main.change_detector.observe_recursive(scene)

func should_update(node: Node) -> bool:
	return (
		main and main.is_session_active() and
		is_instance_valid(node) and
		EditorInterface.get_edited_scene_root()
	)

func _node_properties_changed(node: Node, changed_keys: Array):
	if not should_update(node): return
	
	var scene = EditorInterface.get_edited_scene_root()

	var scene_path = scene.scene_file_path
	var node_path = scene.get_path_to(node)
	var dict = {}
	
	for key in changed_keys:
		dict[key] = node[key]
	
	if main.client.is_active():
		main.server.node_update_request.rpc_id(0, scene_path, node_path, dict)
	elif main.server.is_active():
		main.server.submit_node_update(scene_path, node_path, dict)

func _node_removed(node: Node):
	if not should_update(node): return
	
	var scene = EditorInterface.get_edited_scene_root()
	
	var scene_path = scene.scene_file_path
	var node_path = scene.get_path_to(node)

	if main.client.is_active():
		main.server.node_removal_request.rpc_id(0, scene_path, node_path)
	elif main.server.is_active():
		main.server.submit_node_removal(scene_path, node_path)

func _node_added(node: Node):
	if not should_update(node): return

	var scene = EditorInterface.get_edited_scene_root()
	var scene_path = scene.scene_file_path
	var node_path = scene.get_path_to(node)

	if main.client.is_active():
		main.server.node_add_request.rpc_id(0, scene_path, node_path, node.get_class())
	elif main.server.is_active():
		main.server.submit_node_add(scene_path, node_path, node.get_class())

@rpc("authority", "call_remote", "reliable")
func create_avatar_3d(user_dict: Dictionary) -> GodotTogetherAvatar3D:
	var avatar = avatar_3d_scene.instantiate()
	var user = GodotTogetherUser.from_dict(user_dict)

	avatar.main = self.main
	add_child(avatar)
	
	avatar.set_user(user)
	avatar_3d_markers.append(avatar)
	
	return avatar

@rpc("authority", "call_remote", "reliable")
func create_avatar_2d(user_dict: Dictionary) -> GodotTogetherAvatar2D:
	var avatar = avatar_2d_scene.instantiate()
	var user = GodotTogetherUser.from_dict(user_dict)

	tree_exiting.connect(avatar.queue_free)
	EditorInterface.get_editor_viewport_2d().add_child(avatar)
	
	avatar.set_user(user)
	avatar_2d_markers.append(avatar)
	
	return avatar

func get_avatar_2d(id: int) -> GodotTogetherAvatar2D:
	for i in avatar_2d_markers:
		if i.id == id and i.is_inside_tree(): 
			return i
	
	return null 

func get_avatar_3d(id: int) -> GodotTogetherAvatar3D:
	for i in avatar_3d_markers:
		if i.id == id and i.is_inside_tree(): 
			return i
	
	return null 


@rpc("any_peer")
func update_2d_avatar(vector: Vector2):
	if not main: return
	
	var marker = get_avatar_2d(multiplayer.get_remote_sender_id())
	if not marker: return
	
	marker.set_position_percent(vector)

@rpc("any_peer")
func update_3d_avatar(position: Vector3, rotation: Vector3):
	if not main: return
	
	var marker = get_avatar_3d(multiplayer.get_remote_sender_id())
	if not marker: return
	
	marker.position = position
	marker.rotation = rotation
