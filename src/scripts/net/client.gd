@tool
extends GDTComponent
class_name GDTClient

signal disconnected
signal connecting_finished(success: bool)
signal connection_acknowledged
signal auth_succeed
signal file_received(path: String)

var client_peer = ENetMultiplayerPeer.new()

var current_join_data := GDTJoinData.new()
var server_data: GDTServerAuthResponse = null

var last_received_ping: float = 0.0
var last_sent_ping: float = 0.0
var ignore_alive_ping := false

var connection_is_ack = false
var connection_cancelled := false
var disconnect_reason: GDTUser.DisconnectReason = GDTUser.DisconnectReason.UNKNOWN

var is_fully_synced := false
var last_open_scenes: PackedStringArray = []

func _ready() -> void:
	if not main:
		GDTUtils.printerr_stack("main is null")
		return
	
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.server_disconnected.connect(_disconnected)
	
	if main.logger:
		main.logger.got_known_error.connect(_logger_error)
	
	# Doesn't fire, probably a Godot bug
	#multiplayer.connection_failed.connect(_connecting_finished.bind(false))
	
	report_ready()

func _process(_delta: float) -> void:
	if not main: return
	if not is_active(): return
	
	var now = Time.get_unix_time_from_system()
	
	if (now - last_received_ping) > GDTDual.TIMEOUT:
		printerr("Connection timed out for RPC.")
		main.close_connection()
		
	if (now - last_sent_ping) > GDTDual.PING_INTERVAL:
		main.server._c2s_connection_alive.rpc_id(1)
		last_sent_ping = now

func _connected() -> void:
	if multiplayer.is_server(): return

	_connecting_finished(true)
	
	print("Connected, your ID is: %s" % multiplayer.get_unique_id())
	main.button.set_session_icon(GDTMenuButton.ICON_CLIENT)

	await get_tree().physics_frame
	send_join_data()

func _disconnected() -> void:
	if multiplayer.is_server(): return

	print("Disconnected from server")
	
	var str_reason = "Connection lost. Reason unknown"

	if disconnect_reason < GDTUser.DisconnectReason.size():
		str_reason = GDTUser.disconnect_reason_to_string(disconnect_reason)
	else:
		str_reason = GDTUtils.join([
			"Kicked with unknown reason: %s." % disconnect_reason,
			"You and the host are likely running different versions of GodotTogether."
		], "\n")
		
	main.get_gui().alert(
		str_reason,
		"Disconnected from the server"
	)

	disconnected.emit()
	main.post_session_end()

func _logger_error(error: GDTLogger.KnownError) -> void:
	if not is_active(): return
	
	if error == GDTLogger.KnownError.RPC_CHECKSUM and not connection_is_ack:
		leave_with_error(GDTUser.DisconnectReason.RPC_CHECKSUM_MISMATCH)

func _connecting_finished(success: bool) -> void:
	connecting_finished.emit(success)
	
	if success:
		main.session_start()

func _handle_connecting() -> void:
	var success = MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED

	var status = -1
	var start = Time.get_unix_time_from_system()
	var timeout = start + get_timeout_seconds()

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

func get_timeout_seconds() -> float:
	return main.get_settings().get_setting("client/timeout")

func reset() -> void:
	server_data = null
	connection_is_ack = false
	is_fully_synced = false
	connection_cancelled = false
	disconnect_reason = GDTUser.DisconnectReason.UNKNOWN

func validate_s2c() -> bool:
	if not is_active():
		GDTUtils.printerr_stack("Attempt to call server to client function when client isn't active")
		return false
	
	return true

func leave_with_error(reason := GDTUser.DisconnectReason.UNKNOWN) -> void:
	if not is_active():
		return
	
	disconnect_reason = reason
	
	main.close_connection()
	_disconnected()

func join_server(ip: String, port: int, data := GDTJoinData.new()) -> int:
	main.prepare_session()
	
	reset()
	
	var err = client_peer.create_client(ip, port)
	if err: return err

	print("Connecting to %s:%s..." % [ip, port])

	multiplayer.multiplayer_peer = client_peer
	last_received_ping = Time.get_unix_time_from_system()
	current_join_data = data
	current_join_data.rpc_checksum = main.get_global_rpc_checksum()
	
	_handle_connecting()

	return OK

func send_join_data(obj: GDTJoinData = null) -> void:
	if not obj:
		obj = current_join_data
		
	if not obj:
		GDTUtils.printerr_stack("Join data is null")
		return
	
	var dict = obj.to_dict()
	
	main.server._c2s_receive_join_data.rpc_id(1, dict)

func check_disk_space_for_downloads(data: GDTServerAuthResponse) -> bool:
	var dir = DirAccess.open("res://")
	
	if not dir:
		GDTUtils.printerr_stack("Cannot open project directory. Skipping space check.")
		return true
	
	var space = dir.get_space_left()
	
	if space <= 0: # Not supported
		return true
	
	var download_size = data.get_total_file_size()
	var required = space + GodotTogether.MIN_DISK_SPACE
	
	if download_size > required:
		main.get_gui().alert(
			GDTUtils.join([
				"You have %s left on your disk." % String.humanize_size(space),
				"The project is %s." % String.humanize_size(download_size),
				"You need at least %s (project size + safety buffer) of free space to safely download the project." % String.humanize_size(required)
			], "\n"),
			"Not enough space to download project!"
		)
		
		main.close_connection()
		return false
	
	return true

func download_project() -> void:
	if not server_data:
		GDTUtils.printerr_stack("Cannot download project. server_data null")
		return
	
	if not check_disk_space_for_downloads(server_data):
		return
	
	EditorInterface.get_selection().clear()
	last_open_scenes = EditorInterface.get_open_scenes().duplicate()
	GDTUtils.close_all_scenes()
	
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	
	await main.file_sync.download_project_files(server_data)
	
	if is_active():
		_project_files_downloaded()

@rpc("authority", "reliable")
func _s2c_receive_kick_reason(reason: GDTUser.DisconnectReason) -> void:
	disconnect_reason = reason

@rpc("authority", "reliable")
func _s2c_connection_ack() -> void:
	if connection_is_ack:
		GDTUtils.printerr_stack("Connection already acknowledged")
		return
	
	connection_is_ack = true
	last_received_ping = Time.get_unix_time_from_system()
	connection_acknowledged.emit()

@rpc("authority", "unreliable", "call_remote", GDTDual.NetChannel.MISC)
func _s2c_connection_alive() -> void:
	if not ignore_alive_ping:
		last_received_ping = Time.get_unix_time_from_system()

@rpc("authority", "reliable")
func _s2c_auth_successful(data_dict: Dictionary) -> void:
	print("Server accepted connection")
	
	server_data = GDTServerAuthResponse.from_dict(data_dict)
	
	if not server_data:
		GDTUtils.printerr_stack("Unable to decode response: %s" % data_dict)
		return
	
	var users = GDTUser.from_dict_bulk(server_data.users, main)
	main.dual._users_listed(users)
	
	auth_succeed.emit()
	main.file_sync.pause()
	
	download_project()
	
@rpc("authority", "call_remote", "reliable")
func _s2c_user_connected(user_dict: Dictionary) -> void:
	if not validate_s2c(): return
	
	var user = GDTUser.from_dict(user_dict)
	if not user: return
	
	user.main = main
	main.dual._user_connected(user)

@rpc("authority", "call_remote", "reliable")
func _s2c_user_disconnected(user_dict: Dictionary) -> void:
	if not validate_s2c(): return
	
	var user = GDTUser.from_dict(user_dict)
	if not user: return

	main.dual._user_disconnected(user)

func _project_files_downloaded() -> void:
	print("Project files downloaded")
	
	main.editor_node.force_filesystem_scan()
	
	await get_tree().process_frame
	
	for scene_path in last_open_scenes:
		await GDTUtils.try_open_scene(scene_path)
		await get_tree().process_frame
	
	is_fully_synced = true
	
	await get_tree().process_frame
	main.get_gui().external_file_change_dialog.reload()
	
	await get_tree().process_frame
	
	main.file_sync.resume()

@rpc("authority", "reliable")
func _s2c_receive_chat_message(text: String, user_id: int) -> void:
	if not GDTChat.validate_message(text):
		return
	
	var user = main.dual.get_user_by_id(user_id)
	
	if not user: return
	
	main.get_chat().add_user_message(text, user)

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
	return (
		main and
		multiplayer.multiplayer_peer == client_peer and
		client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	)
