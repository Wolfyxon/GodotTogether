@tool
extends GDTComponent
class_name GDTClient

signal connecting_finished(success: bool)
signal auth_succeed
signal project_files_download_started(amount: int)
signal file_received(path: String)

var client_peer = ENetMultiplayerPeer.new()
var current_join_data := GDTJoinData.new()

var downloaded_file_count := 0
var target_file_count := 0

var connection_cancelled := false

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
	connection_cancelled = false

	var err = client_peer.create_client(ip, port)
	if err: return err

	print("Connecting to %s:%s..." % [ip, port])

	multiplayer.multiplayer_peer = client_peer
	current_join_data = data
	_handle_connecting()

	return OK

@rpc("authority", "reliable")
func auth_successful() -> void:
	print("Server accepted connection, requesting files (if needed)")
	
	auth_succeed.emit()

	main.change_detector.pause()
	main.change_detector.clear()
	main.server.project_files_request.rpc_id(1, GDTFiles.get_file_tree_hashes())


@rpc("authority", "call_remote", "reliable")
func receive_user_list(user_dicts: Array) -> void:
	var users: Array[GDTUser]

	for dict in user_dicts:
		users.append(GDTUser.from_dict(dict))

	main.dual.users_listed.emit(users)

@rpc("authority", "call_remote", "reliable")
func user_connected(user_dict: Dictionary) -> void:
	var user = GDTUser.from_dict(user_dict)

	main.dual.user_connected.emit(user)

@rpc("authority", "call_remote", "reliable")
func user_disconnected(user_dict: Dictionary) -> void:
	var user = GDTUser.from_dict(user_dict)

	main.dual.user_disconnected.emit(user)

func _project_files_downloaded() -> void:
	print("Project files downloaded")

	EditorInterface.get_resource_filesystem().scan()

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
func receive_node_updates(scene_path: String, node_path: NodePath, property_dict: Dictionary) -> void:
	var current_scene = EditorInterface.get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not updating.")
		return
	
	var node = current_scene.get_node_or_null(node_path)
	if not node: return

	main.change_detector.set_node_supression(node, true)	
	main.change_detector.merge(node, property_dict)

	for key in property_dict.keys():
		if key in GDTChangeDetector.IGNORED_NODE_PROPERTIES:
			continue

		var value = property_dict[key]

		if GDTChangeDetector.is_encoded_file_resource(value):
			value = GDTChangeDetector.decode_file_resource(value)

		node[key] = value
	
	await get_tree().create_timer(0.1).timeout # Temporary fix, not great
	main.change_detector.set_node_supression(node, false)

@rpc("authority", "call_remote", "reliable")
func receive_node_removal(scene_path: String, node_path: NodePath) -> void:
	# Freeing nodes during scene reloading / in removed scenes seems to be the cause of crash during join

	var current_scene = EditorInterface.get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not removing.")
		return

	var node = current_scene.get_node_or_null(node_path)
	if not node: return

	prints("rm", node_path)
	node.queue_free()

var fuse = 0

@rpc("authority", "call_remote", "reliable")
func receive_node_add(scene_path: String, node_path: NodePath, node_type: String) -> void:
	assert(fuse < 10, "NODE OVERFLOW (temporary safety measure)")
	fuse += 1

	var current_scene = EditorInterface.get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not adding.")
		return

	var existing = current_scene.get_node_or_null(node_path)
	var path_size = node_path.get_name_count()
	
	var parent_path = node_path.slice(0, path_size - 1)
	var parent: Node = current_scene.get_node_or_null(parent_path)

	if parent_path.is_empty():
		parent = current_scene

	if existing:
		assert(false, "Node %s already exists, not adding" % node_path)

	assert(parent, "Node add failed: Parent (%s) not found for (%s)" % [parent_path, node_path])
	
	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_path.get_name(path_size - 1)

	main.change_detector.suppress_add_signal(scene_path, node_path)
	
	await get_tree().process_frame

	parent.add_child(node)
	node.owner = current_scene

func is_active() -> bool:
	return client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
