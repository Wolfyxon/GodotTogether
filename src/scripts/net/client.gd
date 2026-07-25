@tool
extends GDTComponent
class_name GDTClient

signal disconnected
signal connecting_finished(success: bool)
signal auth_succeed
signal project_files_download_started(amount: int)
signal file_received(path: String)

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
	
	main.file_sync.pause()

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
	
	await get_tree().process_frame
	
	main.file_sync.resume()

@rpc("authority", "reliable")
func begin_project_files_download(file_count: int) -> void:
	print("Begin downloading ", file_count, " files")

	target_file_count = file_count
	project_files_download_started.emit(file_count)

	if file_count == 0:
		_project_files_downloaded()

@rpc("authority", "reliable")
func receive_file(path: String, buffer: PackedByteArray) -> void:
	if not is_fully_synced:
		downloaded_file_count += 1
		
	file_received.emit(path)

	if not GDTValidator.is_path_safe(path):
		print("Server attempted to send file at unsafe location: " + path)
		return
	
	print("Downloading " + path)
	
	GDTFiles.ensure_dir_exists(path)
	
	if FileAccess.file_exists(path):
		var current_buf = FileAccess.get_file_as_bytes(path)
		
		var current_hash = GDTUtils.sha256_of_buffer(current_buf)
		var new_hash = GDTUtils.sha256_of_buffer(buffer)
		
		if current_hash == new_hash:
			print("File didn't change. Not writing")
			return
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	var err = FileAccess.get_open_error()

	assert(err == OK, "Failed to open %s: %d" % [path, err])
	
	f.store_buffer(buffer)
	
	if path.get_extension() == "gd" and "@tool" in buffer.get_string_from_utf8():
		var warning_message = "Tool script detected (%s). It can execute malicious code in your editor!" % path
		print(warning_message)

		if main and main.gui:
			main.gui.alert(warning_message)
	
	print("Saved successfully")
	
	#if path.get_extension() == "tscn":
		#var current_scene = EditorInterface.get_edited_scene_root()
#
		#if current_scene and current_scene.scene_file_path == path:
			#EditorInterface.mark_scene_as_unsaved()
#
		#EditorInterface.reload_scene_from_path(path)

	if not is_fully_synced and target_file_count != 0 and downloaded_file_count >= target_file_count:
		target_file_count = 0
		_project_files_downloaded()

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

func is_active() -> bool:
	return client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
