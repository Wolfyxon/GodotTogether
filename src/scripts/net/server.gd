@tool
extends GDTComponent
class_name GDTServer

signal hosting_started

const JOIN_DELAY: float = 5
const LOCALHOST := [
	"0:0:0:0:0:0:0:1", 
	"127.0.0.1", 
	":1", 
	"localhost"
]

var server_peer = ENetMultiplayerPeer.new()
var ip_join_times = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)

func _connected(id: int) -> void:
	if not multiplayer.is_server(): 
		return

	var now = Time.get_unix_time_from_system()
	var peer = server_peer.get_peer(id)
	var user = GDTUser.new(id, peer, main)
	var ip = peer.get_remote_address()

	print("New connection from %s ID: %d" % [peer.get_remote_address(), id])

	if ip in ip_join_times:
		var last_join = ip_join_times[ip]
		prints(last_join, now, last_join + JOIN_DELAY, JOIN_DELAY)

		if now < last_join + JOIN_DELAY:
			print("User joined too quickly, refusing connection")
			user.kick(GDTUser.DisconnectReason.JOINING_TOO_FAST)

			ip_join_times[ip] = now
			return
		
	ip_join_times[ip] = now

	# The user needs to be added early
	main.dual.users.append(user) 

func _disconnected(id: int) -> void:
	if not multiplayer.is_server(): return

	var user = main.dual.get_user_by_id(id)
	assert(user, "User %d disconnected, but was never listed" % id)

	print("User %s (%d) disconnected" % [user.name, id])
	
	var user_dict = user.to_dict()

	auth_rpc(main.client.user_disconnected, [user_dict])
	main.dual._user_disconnected(user)

func create_server_user() -> GDTUser:
	var user = GDTUser.new(1, null)

	user.name = GDTSettings.get_setting("username")
	user.type = GDTUser.Type.HOST
	user.main = main
	user.id = 1

	user.auth()

	return user

func get_authenticated_users(include_server := true) -> Array[GDTUser]:
	var res: Array[GDTUser] = []

	for i in main.dual.users:
		if i.authenticated and (include_server or i.type != GDTUser.Type.HOST) and (not i.peer or i.is_peer_connected()):
			res.append(i)

	return res

func get_authenticated_ids(include_server := true) -> Array[int]:
	var res: Array[int] = []

	for i in get_authenticated_users(include_server):
		res.append(i.id)

	return res

func start_hosting(port: int, max_clients := 10) -> int:
	main.prepare_session()

	var err = server_peer.create_server(port, max_clients)
	
	if err:
		push_error("Failed to start server: %d" % err)
		return err

	print("Server started. Port: %s Max clients: %s" % [port, max_clients])

	multiplayer.multiplayer_peer = server_peer

	main.dual._users_listed([
		create_server_user()
	])

	_post_start()

	return err

func _post_start() -> void:
	await get_tree().process_frame

	main.button.set_session_icon(GDTMenuButton.ICON_SERVER)
	hosting_started.emit()

func id_has_permission(peer_id: int, permission: GodotTogether.Permission) -> bool:
	var user = main.dual.get_user_by_id(peer_id)

	return user != null and user.has_permission(permission)

func get_user_dicts() -> Array[Dictionary]:
	var dicts: Array[Dictionary] = []

	for user in get_authenticated_users():
		dicts.append(user.to_dict())

	return dicts

@rpc("any_peer", "reliable")
func receive_chat_message(text: String) -> void:
	var id = multiplayer.get_remote_sender_id()
	var user = main.dual.get_user_by_id(id)

	if not user: return
	if not user.authenticated: return

	if text == "": return
	if text.length() > GDTChat.MAX_MESSAGE_LEN: return

	submit_chat_message(id, text)

func submit_chat_message(user_id: int, text) -> void:
	auth_rpc(main.chat.receive_user_message, [text, user_id])
	main.chat.receive_user_message(text, user_id)

@rpc("any_peer", "call_remote", "reliable")
func receive_join_data(data_dict: Dictionary) -> void:
	var id = multiplayer.get_remote_sender_id()
	var user = main.dual.get_user_by_id(id)

	var data = GDTJoinData.from_dict(data_dict)
	var server_password = GDTSettings.get_setting("server/password")
	
	if data.password != server_password:
		print("Invalid password for user %d" % id)
		user.kick(GDTUser.DisconnectReason.PASSWORD_INVALID)
		return

	user.name = data.username
	
	if GDTSettings.get_setting("server/require_approval"):
		user.pending = true
		var ip = user.peer.get_remote_address() if user.peer else "Local"
		main.toaster.push_toast("User %s (%s) wants to join. Check Pending Users tab." % [user.name, ip])
		return
	
	user.auth()

@rpc("any_peer", "call_remote", "reliable")
func project_files_request(hashes: Dictionary) -> void:
	var id = multiplayer.get_remote_sender_id()
	
	var local_hashes = GDTFiles.get_file_tree_hashes()

	var files_to_send = []

	for path in local_hashes.keys():
		var local_hash = local_hashes[path]
		
		if not hashes.has(path) or local_hash != hashes[path]:			
			if FileAccess.file_exists(path):
				files_to_send.append(path)

	main.client.begin_project_files_download.rpc_id(id, files_to_send.size())

	for path in files_to_send:
		var buf = FileAccess.get_file_as_bytes(path)
		if not buf: continue
		
		print("Sending " + path)
		main.client.receive_file.rpc_id(id, path, buf)

	#main.client.project_files_downloaded.rpc_id(id)

@rpc("any_peer", "call_remote", "reliable")
func broadcast_restart():
	if not GDTSettings.get_setting("dev/restart_broadcast"):
		return

	for user in main.dual.users:
		main.dual.restart.rpc_id(user.id)
	
	await get_tree().create_timer(0.5).timeout
	
	main.dual.restart()

@rpc("any_peer", "call_remote", "reliable")
func node_update_request(scene_path: String, node_path: NodePath, property_dict: Dictionary) -> void:
	var id = multiplayer.get_remote_sender_id()
	
	if not id_has_permission(id, GodotTogether.Permission.EDIT_SCENES): return
	
	main.client.receive_node_updates(scene_path, node_path, property_dict)
	submit_node_update(scene_path, node_path, property_dict, id)

@rpc("any_peer", "call_remote", "reliable")
func node_removal_request(scene_path: String, node_path: NodePath) -> void:
	var id = multiplayer.get_remote_sender_id()

	if not id_has_permission(multiplayer.get_remote_sender_id(), GodotTogether.Permission.EDIT_SCENES): return

	submit_node_removal(scene_path, node_path, id)

@rpc("any_peer", "call_remote", "reliable")
func node_add_request(scene_path: String, node_path: NodePath, node_type: String, properties: Dictionary) -> void:
	if not ClassDB.class_exists(node_type):
		print("Invalid node type: %s" % node_type)
		return
	
	if not id_has_permission(multiplayer.get_remote_sender_id(), GodotTogether.Permission.EDIT_SCENES): return

	submit_node_add(scene_path, node_path, node_type, properties)

func submit_node_removal(scene_path: String, node_path: NodePath, sender := 0) -> void:
	main.client.receive_node_removal(scene_path, node_path)
	auth_rpc(main.client.receive_node_removal, [scene_path, node_path], [sender])

func submit_node_update(scene_path: String, node_path: NodePath, property_dict: Dictionary, sender := 0) -> void:
	main.client.receive_node_updates(scene_path, node_path, property_dict)
	auth_rpc(main.client.receive_node_updates, [scene_path, node_path, property_dict], [sender])

func submit_node_add(scene_path: String, node_path: NodePath, node_type: String, properties: Dictionary, sender := 0) -> void:
	main.client.receive_node_add(scene_path, node_path, node_type, properties)
	auth_rpc(main.client.receive_node_add, [scene_path, node_path, node_type, properties], [sender])

@rpc("any_peer", "call_remote", "reliable")
func node_rename_request(scene_path: String, old_path: NodePath, new_name: String) -> void:
	if not id_has_permission(multiplayer.get_remote_sender_id(), GodotTogether.Permission.EDIT_SCENES): return
	
	submit_node_rename(scene_path, old_path, new_name)

@rpc("any_peer", "call_remote", "reliable")
func node_reparent_request(scene_path: String, node_path: NodePath, new_parent_path: NodePath, new_index: int) -> void:
	if not id_has_permission(multiplayer.get_remote_sender_id(), GodotTogether.Permission.EDIT_SCENES): return
	
	submit_node_reparent(scene_path, node_path, new_parent_path, new_index)

func submit_node_rename(scene_path: String, old_path: NodePath, new_name: String, sender := 0) -> void:
	main.client.receive_node_rename(scene_path, old_path, new_name)
	auth_rpc(main.client.receive_node_rename, [scene_path, old_path, new_name], [sender])

func submit_node_reparent(scene_path: String, node_path: NodePath, new_parent_path: NodePath, new_index: int, sender := 0) -> void:
	main.client.receive_node_reparent(scene_path, node_path, new_parent_path, new_index)
	auth_rpc(main.client.receive_node_reparent, [scene_path, node_path, new_parent_path, new_index], [sender])

@rpc("any_peer", "call_remote", "reliable")
func file_add_from_client(path: String, buffer: PackedByteArray) -> void:
	var id = multiplayer.get_remote_sender_id()

	if not id_has_permission(id, GodotTogether.Permission.ADD_CUSTOM_FILES): return
	if not GDTValidator.is_path_safe(path): return

	print("[SERVER] Received file add from client %d: %s" % [id, path])
	main.change_detector.suppress_filesystem_sync = true
	
	var new_hash = buffer.get_string_from_utf8().sha256_text()
	main.change_detector.cached_file_hashes[path] = new_hash
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(buffer)
		f.close()
	
	EditorInterface.get_resource_filesystem().scan()
	
	main.change_detector.suppress_filesystem_sync = false
	
	broadcast_file_add_with_buffer(path, buffer, id)

@rpc("any_peer", "call_remote", "reliable")
func file_modify_from_client(path: String, buffer: PackedByteArray) -> void:
	var id = multiplayer.get_remote_sender_id()

	if not id_has_permission(id, GodotTogether.Permission.MODIFY_CUSTOM_FILES): return
	if not GDTValidator.is_path_safe(path): return

	print("[SERVER] Received file modify from client %d: %s" % [id, path])
	main.change_detector.suppress_filesystem_sync = true
	
	var new_hash = buffer.get_string_from_utf8().sha256_text()
	main.change_detector.cached_file_hashes[path] = new_hash
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(buffer)
		f.close()
	
	EditorInterface.get_resource_filesystem().scan()
	
	main.change_detector.suppress_filesystem_sync = false
	
	broadcast_file_modify_with_buffer(path, buffer, id)

@rpc("any_peer", "call_remote", "reliable")
func file_remove_from_client(path: String) -> void:
	var id = multiplayer.get_remote_sender_id()

	if not id_has_permission(id, GodotTogether.Permission.DELETE_SCRIPTS): return
	if not GDTValidator.is_path_safe(path): return

	print("[SERVER] Received file remove from client %d: %s" % [id, path])
	main.change_detector.suppress_filesystem_sync = true
	main.change_detector.cached_file_hashes.erase(path)
	
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	
	EditorInterface.get_resource_filesystem().scan()
	
	await get_tree().create_timer(1.0).timeout
	main.change_detector.suppress_filesystem_sync = false
	
	broadcast_file_remove(path, id)

func broadcast_file_add(path: String, sender := 0) -> void:
	var buffer = FileAccess.get_file_as_bytes(path)
	if buffer:
		broadcast_file_add_with_buffer(path, buffer, sender)

func broadcast_file_add_with_buffer(path: String, buffer: PackedByteArray, sender := 0) -> void:
	print("[SERVER] Broadcasting file add to clients: ", path)
	auth_rpc(main.client.sync_file_add, [path, buffer], [sender])

func broadcast_file_modify(path: String, sender := 0) -> void:
	var buffer = FileAccess.get_file_as_bytes(path)
	if buffer:
		broadcast_file_modify_with_buffer(path, buffer, sender)

func broadcast_file_modify_with_buffer(path: String, buffer: PackedByteArray, sender := 0) -> void:
	print("[SERVER] Broadcasting file modify to clients: ", path)
	auth_rpc(main.client.sync_file_modify, [path, buffer], [sender])

func broadcast_file_remove(path: String, sender := 0) -> void:
	print("[SERVER] Broadcasting file remove to clients: ", path)
	auth_rpc(main.client.sync_file_remove, [path], [sender])

func auth_rpc(fn: Callable, args: Array, exclude_ids: Array[int] = []) -> void:
	for i in get_authenticated_ids(false):
		if not i in exclude_ids:
			fn.rpc_id.callv([i] + args)

func is_active() -> bool:
	return server_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

static func is_local(ip: String) -> bool:
	if ip in LOCALHOST: return true
	
	var split = ip.split(".")
	if split.size() != 4:
		push_error(ip + " doesn't seem to be a valid IP address: size not equal to 4. Assuming this is not a local address.")
		return false
	
	var a = int(split[0])
	var b = int(split[1])
	#var c = int(split[2])
	#var d = int(split[3])
	
	if a == 127: return true
	if a == 172 and b >= 16 and b <= 31: return true
	if a == 192 and b == 168: return true
	
	return false

func get_pending_users() -> Array[GDTUser]:
	var res: Array[GDTUser] = []
	
	for i in main.dual.users:
		if i.pending and (not i.peer or i.is_peer_connected()):
			res.append(i)
	
	return res
