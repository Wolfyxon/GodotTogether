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
	main.change_detector.node_renamed.connect(_node_renamed)
	main.change_detector.node_reparented.connect(_node_reparented)
	
	update_timer.timeout.connect(_update)
	update_timer.one_shot = false
	update_timer.wait_time = 0.02
	add_child(update_timer)
	update_timer.start()

func _update() -> void:
	if not main: return
	if not main.is_session_active(): return
	
	var viewport_2d = EditorInterface.get_editor_viewport_2d()
	if not viewport_2d: return
	
	var mPos = viewport_2d.get_mouse_position()
	
	if mPos != prev_mouse_pos and DisplayServer.window_is_focused():
		prev_mouse_pos = mPos
		update_2d_avatar.rpc(mPos)
	
	var viewport_3d = EditorInterface.get_editor_viewport_3d()
	if not viewport_3d: return
	
	var new_camera = viewport_3d.get_camera_3d()
	if not new_camera or not is_instance_valid(new_camera): 
		return
	
	if new_camera != camera:
		camera = new_camera
		prev_3d_pos = Vector3.ZERO
		prev_3d_rot = Vector3.ZERO
		return
	
	if camera.position == Vector3.ZERO and camera.rotation == Vector3.ZERO:
		return
	
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
	if not user in users:
		users.append(user)
	
	user_connected.emit(user)
	
	if should_notify_user_connection():
		var ip = user.peer.get_remote_address() if user.peer else "Local"
		main.toaster.push_toast("User %s (%s) joined" % [user.name, ip])

func _user_disconnected(user: GDTUser) -> void:
	users.erase(user)
	user_disconnected.emit(user)
	
	if should_notify_user_connection():
		var ip = user.peer.get_remote_address() if user.peer else "Local"
		main.toaster.push_toast("User %s (%s) disconnected" % [user.name, ip])

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
		main.server.node_update_request.rpc_id(1, scene_path, node_path, dict)
	elif main.server.is_active():
		main.server.submit_node_update(scene_path, node_path, dict)

func _node_removed(node: Node, node_path: NodePath) -> void:
	await get_tree().process_frame
	if is_instance_valid(node) and node.is_inside_tree():
		return

	if not should_update(node): return
	
	var scene = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene): return
	
	var scene_path = scene.scene_file_path

	if main.client.is_active():
		main.server.node_removal_request.rpc_id(1, scene_path, node_path)
	elif main.server.is_active():
		main.server.submit_node_removal(scene_path, node_path)

func _node_added(node: Node) -> void:
	if not should_update(node): return

	var scene = EditorInterface.get_edited_scene_root()
	var scene_path = scene.scene_file_path
	var node_path = scene.get_path_to(node)
	
	var properties = {}
	for key in GDTChangeDetector.get_property_keys(node):
		var value = node[key]
		if value is Resource:
			value = GDTChangeDetector.encode_resource(value)
		properties[key] = value

	if main.client.is_active():
		main.server.node_add_request.rpc_id(1, scene_path, node_path, node.get_class(), properties)
	elif main.server.is_active():
		main.server.submit_node_add(scene_path, node_path, node.get_class(), properties)

func _node_renamed(node: Node, old_name: String, new_name: String) -> void:
	if not should_update(node): return
	
	var scene = EditorInterface.get_edited_scene_root()
	var parent = node.get_parent()
	
	var old_path = scene.get_path_to(parent).get_concatenated_names() + "/" + old_name
	var old_node_path = NodePath(old_path)
	
	if main.client.is_active():
		main.server.node_rename_request.rpc_id(1, scene.scene_file_path, old_node_path, new_name)
	elif main.server.is_active():
		main.server.submit_node_rename(scene.scene_file_path, old_node_path, new_name)

func _node_reparented(node: Node, old_parent: Node, new_parent: Node) -> void:
	if not should_update(node): return
	
	var scene = EditorInterface.get_edited_scene_root()
	var scene_path = scene.scene_file_path
	
	var old_path_str = scene.get_path_to(old_parent).get_concatenated_names()
	if old_path_str != "":
		old_path_str += "/"
	old_path_str += node.name
	var node_path = NodePath(old_path_str)

	var new_parent_path = scene.get_path_to(new_parent)
	var new_index = node.get_index()

	if main.client.is_active():
		main.server.node_reparent_request.rpc_id(1, scene_path, node_path, new_parent_path, new_index)
	elif main.server.is_active():
		main.server.submit_node_reparent(scene_path, node_path, new_parent_path, new_index)

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

@rpc("authority", "call_remote", "reliable")
func restart() -> void:
	if not GDTSettings.get_setting("dev/restart_broadcast"):
		return

	var id = multiplayer.get_remote_sender_id()

	print("==================================")
	print("! RESTART BROADCAST !")
	print("Sender ID: %s" % id)
	print("A plugin restart broadcast was activated. If this happened unintentionally please turn it off:")
	print("GodotTogether menu -> Settings -> Advanced -> 'Enable restart broadcast'")
	print("==================================")

	EditorInterface.get_editor_toaster().push_toast(
		"Restart broadcast received. Check console.", 
		EditorToaster.SEVERITY_WARNING
	)

	main.restart()

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
func update_2d_avatar(position: Vector2) -> void:
	if not main: return
	
	var marker = get_avatar_2d(multiplayer.get_remote_sender_id())
	if not marker: return
	
	marker.global_position = position

@rpc("any_peer")
func update_3d_avatar(position: Vector3, rotation: Vector3) -> void:
	if not main: return
	if position == Vector3.ZERO and rotation == Vector3.ZERO: return
	
	var marker = get_avatar_3d(multiplayer.get_remote_sender_id())
	if not marker: return
	
	marker.position = position
	marker.rotation = rotation
