@tool
extends GDTComponent
class_name GDTClient

signal disconnected
signal connecting_finished(success: bool)
signal auth_succeed
signal project_files_download_started(amount: int)
signal file_received(path: String)

var ignored_node_properties = GDTChangeDetector.IGNORED_PROPERTIES.Node

var client_peer = ENetMultiplayerPeer.new()
var current_join_data := GDTJoinData.new()

var downloaded_file_count := 0
var target_file_count := 0

var connection_cancelled := false
var disconnect_reason: GDTUser.DisconnectReason = 0

var is_fully_synced := false
var last_open_scenes: PackedStringArray = []

func _ready() -> void:
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.server_disconnected.connect(_disconnected)

	# Doesn't fire, probably a Godot bug
	#multiplayer.connection_failed.connect(_connecting_finished.bind(false))

func _connected() -> void:
	if multiplayer.is_server(): return

	_connecting_finished(true)
	
	print("Connected, your ID is: %s" % multiplayer.get_unique_id())
	main.button.set_session_icon(GDTMenuButton.ICON_CLIENT)

	await get_tree().physics_frame
	main.server.receive_join_data.rpc_id(1, current_join_data.to_dict())

func _disconnected() -> void:
	if multiplayer.is_server(): return

	print("Disconnected from server")
	
	is_fully_synced = false

	main.gui.alert(
		GDTUser.disconnect_reason_to_string(disconnect_reason),
		"Disconnected from the server"
	)

	disconnected.emit()
	main.post_session_end()

func _connecting_finished(success: bool) -> void:
	connecting_finished.emit(success)

func _handle_connecting() -> void:
	var connecting = MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING
	var success = MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED

	var status = -1

	var start = Time.get_unix_time_from_system()
	var timeout = start + 10

	while (status == -1 or status != success) and Time.get_unix_time_from_system() < timeout and not connection_cancelled:
		status = client_peer.get_connection_status()
		await get_tree().process_frame

	if connection_cancelled:
		client_peer.close()
		_connecting_finished(false)
		return

	if client_peer.get_connection_status() != success:
		client_peer.close()
		_connecting_finished(false)

func join(ip: String, port: int, data := GDTJoinData.new()) -> int:
	main.prepare_session()

	disconnect_reason = GDTUser.DisconnectReason.UNKNOWN
	connection_cancelled = false
	is_fully_synced = false

	var err = client_peer.create_client(ip, port)
	if err: return err

	print("Connecting to %s:%s..." % [ip, port])

	multiplayer.multiplayer_peer = client_peer
	current_join_data = data
	_handle_connecting()

	return OK

@rpc("authority", "reliable")
func kick(reason: GDTUser.DisconnectReason) -> void:
	disconnect_reason = reason

@rpc("authority", "reliable")
func auth_successful() -> void:
	print("Server accepted connection, requesting files (if needed)")
	
	auth_succeed.emit()

	main.change_detector.pause()
	main.change_detector.clear()

	last_open_scenes = EditorInterface.get_open_scenes().duplicate()
	GDTUtils.close_all_scenes()

	await get_tree().create_timer(0.25).timeout

	main.server.project_files_request.rpc_id(1, GDTFiles.get_file_tree_hashes())

@rpc("authority", "call_remote", "reliable")
func receive_user_list(user_dicts: Array) -> void:
	var users: Array[GDTUser]

	for dict in user_dicts:
		users.append(GDTUser.from_dict(dict))

	main.dual._users_listed(users)

@rpc("authority", "call_remote", "reliable")
func user_connected(user_dict: Dictionary) -> void:
	var user = GDTUser.from_dict(user_dict)

	main.dual._user_connected(user)

@rpc("authority", "call_remote", "reliable")
func user_disconnected(user_dict: Dictionary) -> void:
	var user = GDTUser.from_dict(user_dict)

	main.dual._user_disconnected(user)

func _project_files_downloaded() -> void:
	print("Project files downloaded")
	
	EditorInterface.get_resource_filesystem() # reloads the script, breaking await ._.

	for scene_path in last_open_scenes:
		await GDTUtils.try_open_scene(scene_path)
		await get_tree().process_frame
	
	is_fully_synced = true
	main.change_detector.resume()
	main.change_detector.observe_current_scene()

@rpc("authority", "reliable")
func begin_project_files_download(file_count: int) -> void:
	print("Begin downloading ", file_count, " files")

	target_file_count = file_count
	project_files_download_started.emit(file_count)

	if file_count == 0:
		_project_files_downloaded()

@rpc("authority", "reliable")
func receive_file(path: String, buffer: PackedByteArray) -> void:
	downloaded_file_count += 1
	file_received.emit(path)

	if not GDTValidator.is_path_safe(path):
		print("Server attempted to send file at unsafe location: " + path)
		return
	
	print("Downloading " + path)
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	var err = FileAccess.get_open_error()

	assert(err == OK, "Failed to open %s: %d" % [path, err])
	
	f.store_buffer(buffer)
	
	print("Saved successfully")
	
	if path.get_extension() == "tscn":
		var current_scene = EditorInterface.get_edited_scene_root()

		if current_scene and current_scene.scene_file_path == path:
			EditorInterface.mark_scene_as_unsaved()

		EditorInterface.reload_scene_from_path(path)

	if target_file_count != 0 and downloaded_file_count >= target_file_count:
		target_file_count = 0
		_project_files_downloaded()

@rpc("authority", "call_remote", "reliable")
func sync_file_add(path: String, buffer: PackedByteArray) -> void:
	if not GDTValidator.is_path_safe(path): return

	print("[CLIENT] Receiving file add: ", path)
	main.change_detector.suppress_filesystem_sync = true
	
	var new_hash = buffer.get_string_from_utf8().sha256_text()
	main.change_detector.cached_file_hashes[path] = new_hash

	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(buffer)
		f.close()

	EditorInterface.get_resource_filesystem().scan()

	main.change_detector.suppress_filesystem_sync = false

@rpc("authority", "call_remote", "reliable")
func sync_file_modify(path: String, buffer: PackedByteArray) -> void:
	if not GDTValidator.is_path_safe(path): return

	print("[CLIENT] Receiving file modify: ", path)
	main.change_detector.suppress_filesystem_sync = true

	var new_hash = buffer.get_string_from_utf8().sha256_text()
	main.change_detector.cached_file_hashes[path] = new_hash
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(buffer)
		f.close()
	
	EditorInterface.get_resource_filesystem().scan()
	
	main.change_detector.suppress_filesystem_sync = false

@rpc("authority", "call_remote", "reliable")
func sync_file_remove(path: String) -> void:
	if not GDTValidator.is_path_safe(path): return

	print("[CLIENT] Receiving file remove: ", path)
	main.change_detector.suppress_filesystem_sync = true
	main.change_detector.cached_file_hashes.erase(path)

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	EditorInterface.get_resource_filesystem().scan()

	await get_tree().create_timer(1.0).timeout
	main.change_detector.suppress_filesystem_sync = false

func _apply_change_to_unloaded_scene(scene_path: String, apply_func: Callable) -> void:
	if not FileAccess.file_exists(scene_path):
		push_error("Scene file not found for background update: " + scene_path)
		return

	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		push_error("Failed to load scene for background update: " + scene_path)
		return

	var scene_instance = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if not scene_instance:
		push_error("Failed to instantiate scene for background update: " + scene_path)
		return

	var success = apply_func.call(scene_instance)

	if success:
		var new_packed_scene = PackedScene.new()
		var result = new_packed_scene.pack(scene_instance)

		if result == OK:
			ResourceSaver.save(new_packed_scene, scene_path)
		else:
			push_error("Failed to pack scene after background update: " + scene_path)

	scene_instance.queue_free()

@rpc("authority", "call_remote", "reliable")
func receive_node_updates(scene_path: String, node_path: NodePath, property_dict: Dictionary) -> void:
	var scene = GDTUtils.get_loaded_scene_root(scene_path)

	if not scene:
		var apply_changes = func(scene_root: Node):
			var node = scene_root.get_node_or_null(node_path)
			if not node: return false

			for key in property_dict.keys():
				var value = property_dict[key]
				if GDTChangeDetector.is_encoded_resource(value):
					value = GDTChangeDetector.decode_resource(value)
				node.set(key, value)
			return true

		_apply_change_to_unloaded_scene(scene_path, apply_changes)
		return

	var node = scene.get_node_or_null(node_path)
	
	if not node: 
		return

	main.change_detector.set_node_supression(node, true)

	for key in property_dict.keys():
		if key in ignored_node_properties:
			continue

		var value = property_dict[key]

		if GDTChangeDetector.is_encoded_resource(value):
			value = GDTChangeDetector.decode_resource(value)

		node[key] = value
	
	main.change_detector.merge(node, property_dict)

	await get_tree().create_timer(0.1).timeout
	main.change_detector.set_node_supression(node, false)

@rpc("authority", "call_remote", "reliable")
func receive_node_removal(scene_path: String, node_path: NodePath) -> void:
	var scene = EditorInterface.get_edited_scene_root()

	if not scene:
		var apply_removal = func(scene_root: Node):
			var node = scene_root.get_node_or_null(node_path)
			if not node: return false

			node.get_parent().remove_child(node)
			node.queue_free()

			return true
		
		_apply_change_to_unloaded_scene(scene_path, apply_removal)
		return

	var node = scene.get_node_or_null(node_path)
	if not node: return

	prints("rm", node_path)
	node.queue_free()

@rpc("authority", "call_remote", "reliable")
func receive_node_add(scene_path: String, node_path: NodePath, node_type: String, properties: Dictionary) -> void:
	var scene = GDTUtils.get_loaded_scene_root(scene_path)

	if not scene:
		var apply_add = func(scene_root: Node):
			if scene_root.get_node_or_null(node_path): return false

			var path_size = node_path.get_name_count()
			var parent_path = node_path.slice(0, path_size - 1)
			var parent = scene_root.get_node_or_null(parent_path)
			if parent_path.is_empty(): parent = scene_root

			if not parent: return false

			var node: Node = ClassDB.instantiate(node_type)
			node.name = node_path.get_name(path_size - 1)
			parent.add_child(node)
			node.owner = scene_root

			for key in properties.keys():
				if key == "name": continue

				var value = properties[key]
				
				if GDTChangeDetector.is_encoded_resource(value):
					value = GDTChangeDetector.decode_resource(value)
				
				node[key] = value
			return true

		_apply_change_to_unloaded_scene(scene_path, apply_add)
		return

	var existing = scene.get_node_or_null(node_path)

	if existing:
		print("Node %s already exists, not adding" % node_path)
		return

	var path_size = node_path.get_name_count()
	var parent_path = node_path.slice(0, path_size - 1)
	var parent: Node = scene.get_node_or_null(parent_path)

	if parent_path.is_empty():
		parent = scene

	if not parent:
		print("Node add failed: Parent (%s) not found for (%s)" % [parent_path, node_path])
		return

	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_path.get_name(path_size - 1)

	main.change_detector.suppress_add_signal(scene_path, node_path)

	await get_tree().process_frame

	parent.add_child(node)
	node.owner = scene

	main.change_detector.observe(node)

	if properties.size() > 0:
		for key in properties.keys():
			if key == "name": continue

			var value = properties[key]
			if GDTChangeDetector.is_encoded_resource(value):
				value = GDTChangeDetector.decode_resource(value)
			
			node[key] = value

		main.change_detector.merge(node, properties)

@rpc("authority", "call_remote", "reliable")
func receive_node_rename(scene_path: String, old_path: NodePath, new_name: String) -> void:
	var scene = GDTUtils.get_loaded_scene_root(scene_path)

	if not scene:
		var apply_rename = func(scene_root: Node):
			var node = scene_root.get_node_or_null(old_path)
			if not node: return false
			node.name = new_name
			return true
		_apply_change_to_unloaded_scene(scene_path, apply_rename)
		return

	var node = scene.get_node_or_null(old_path)

	if not node: 
		print("Node to rename not found: %s" % old_path)
		return

	main.change_detector.set_node_supression(node, true)
	node.name = new_name
	await get_tree().create_timer(0.1).timeout
	main.change_detector.set_node_supression(node, false)

@rpc("authority", "call_remote", "reliable")
func receive_node_reparent(scene_path: String, node_path: NodePath, new_parent_path: NodePath, new_index: int) -> void:
	var scene = EditorInterface.get_edited_scene_root()

	if not scene:
		var apply_reparent = func(scene_root: Node):
			var node = scene_root.get_node_or_null(node_path)
			var new_parent = scene_root.get_node_or_null(new_parent_path)
			if new_parent_path.is_empty(): new_parent = scene_root

			if not node or not new_parent: return false

			var old_parent = node.get_parent()
			old_parent.remove_child(node)
			new_parent.add_child(node)
			new_parent.move_child(node, new_index)
			return true
		
		_apply_change_to_unloaded_scene(scene_path, apply_reparent)
		return

	var node = scene.get_node_or_null(node_path)
	var new_parent = scene.get_node_or_null(new_parent_path)

	if new_parent_path.is_empty():
		new_parent = scene

	if not node or not new_parent:
		print("Node or parent not found for reparenting")
		return

	main.change_detector.set_node_supression(node, true)

	var old_parent = node.get_parent()
	old_parent.remove_child(node)
	new_parent.add_child(node)
	new_parent.move_child(node, new_index)

	await get_tree().create_timer(0.1).timeout
	main.change_detector.set_node_supression(node, false)

func is_active() -> bool:
	return client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
