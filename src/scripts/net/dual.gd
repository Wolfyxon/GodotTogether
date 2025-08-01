@tool
extends GDTComponent
class_name GDTDual

signal user_connected(user: GDTUser)
signal user_disconnected(user: GDTUser)
signal users_listed(users: Array[GDTUser])

var camera: Camera3D
var update_timer = Timer.new()
var users: Array[GDTUser]

var prev_mouse_pos := Vector2()
var prev_3d_pos := Vector3()
var prev_3d_rot := Vector3()

var avatar_3d_scene = load("res://addons/GodotTogether/src/scenes/Avatar3D/Avatar3D.tscn")
var avatar_2d_scene = load("res://addons/GodotTogether/src/scenes/Avatar2D/Avatar2D.tscn")

var avatar_3d_markers: Array[GDTAvatar3D] = []
var avatar_2d_markers: Array[GDTAvatar2D] = []

func _ready() -> void:
	if not main: return
	camera = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	
	main.change_detector.scene_changed.connect(_scene_changed)
	main.change_detector.node_properties_changed.connect(_node_properties_changed)
	main.change_detector.node_removed.connect(_node_removed)
	main.change_detector.node_added.connect(_node_added)
	
	update_timer.timeout.connect(_update)
	update_timer.one_shot = false
	update_timer.wait_time = 0.02
	add_child(update_timer)
	update_timer.start()

func _update() -> void:
	if not main: return
	if not main.is_session_active(): return
	
	var viewport_2d = EditorInterface.get_editor_viewport_2d()
	var mPos = viewport_2d.get_mouse_position() / Vector2(viewport_2d.size)
	
	if mPos != prev_mouse_pos and DisplayServer.window_is_focused():
		prev_mouse_pos = mPos
		update_2d_avatar.rpc(mPos)
		
	if camera.position != prev_3d_pos or camera.rotation != prev_3d_rot:
		prev_3d_pos = camera.position
		prev_3d_rot = camera.rotation
		
		update_3d_avatar.rpc(camera.position, camera.rotation)

func _peer_connected(id: int) -> void:
	pass
	
func _peer_disconnected(id: int) -> void:
	print("Peer %s disconnected" % id)

	var marker3d = get_avatar_3d(id)
	var marker2d = get_avatar_2d(id)
	
	if marker2d: 
		avatar_2d_markers.erase(marker2d)
		marker2d.queue_free()
	if marker3d: 
		avatar_3d_markers.erase(marker3d)
		marker3d.queue_free()

func _user_connected(user: GDTUser) -> void:
	user_connected.emit(user)

	if user in users:
		users.append(user)

	if should_notify_user_connection():
		main.toaster.push_toast("User %s (%s) joined" % [user.name, user.id])

func _user_disconnected(user: GDTUser) -> void:
	users.erase(user)
	user_disconnected.emit(user)
	
	if should_notify_user_connection():
		main.toaster.push_toast("User %s (%s) disconnected" % [user.name, user.id])

func _users_listed(users: Array[GDTUser]) -> void:
	self.users = users
	users_listed.emit(users)

func _scene_changed() -> void:	
	main.change_detector.observe_current_scene()

func should_notify_user_connection() -> bool:
	return GDTSettings.get_setting("notifications/users")

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
		var value = node[key]

		if value is Resource:
			value = GDTChangeDetector.encode_resource(value)

		dict[key] = value
	
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

func get_user_by_id(id: int) -> GDTUser:
	for i in users:
		if i.id == id:
			return i

	return

func get_server_user() -> GDTUser:
	for i in users:
		if i.type == GDTUser.Type.HOST:
			return i

	return

@rpc("authority", "call_remote", "reliable")
func create_avatar_3d(user_dict: Dictionary) -> GDTAvatar3D:
	var avatar = avatar_3d_scene.instantiate()
	var user = GDTUser.from_dict(user_dict)

	avatar.main = self.main
	add_child(avatar)
	
	avatar.set_user(user)
	avatar_3d_markers.append(avatar)
	
	return avatar

@rpc("authority", "call_remote", "reliable")
func create_avatar_2d(user_dict: Dictionary) -> GDTAvatar2D:
	var avatar = avatar_2d_scene.instantiate()
	var user = GDTUser.from_dict(user_dict)

	tree_exiting.connect(avatar.queue_free)
	EditorInterface.get_editor_viewport_2d().add_child(avatar)
	
	avatar.set_user(user)
	avatar_2d_markers.append(avatar)
	
	return avatar

func get_avatar_2d(id: int) -> GDTAvatar2D:
	for i in avatar_2d_markers:
		if is_instance_valid(i) and i.id == id and i.is_inside_tree(): 
			return i
	
	return null 

func get_avatar_3d(id: int) -> GDTAvatar3D:
	for i in avatar_3d_markers:
		if is_instance_valid(i) and i.id == id and i.is_inside_tree(): 
			return i
	
	return null 

func clear_avatars() -> void:
	for i in avatar_3d_markers:
		if is_instance_valid(i):
			i.queue_free()

	for i in avatar_2d_markers:
		if is_instance_valid(i):
			i.queue_free()

	avatar_3d_markers.clear()
	avatar_3d_markers.clear()

@rpc("any_peer")
func update_2d_avatar(vector: Vector2) -> void:
	if not main: return
	
	var marker = get_avatar_2d(multiplayer.get_remote_sender_id())
	if not marker: return
	
	marker.set_position_percent(vector)

@rpc("any_peer")
func update_3d_avatar(position: Vector3, rotation: Vector3) -> void:
	if not main: return
	
	var marker = get_avatar_3d(multiplayer.get_remote_sender_id())
	if not marker: return
	
	marker.position = position
	marker.rotation = rotation
