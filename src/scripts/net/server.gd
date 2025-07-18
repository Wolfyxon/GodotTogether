@tool
extends GDTComponent
class_name GDTServer

const LOCALHOST := [
	"0:0:0:0:0:0:0:1", 
	"127.0.0.1", 
	":1", 
	"localhost"
]

var server_peer = ENetMultiplayerPeer.new()
var connected_users: Array[GDTUser] = []

func _ready():
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)

func _connected(id: int):
	if not multiplayer.is_server(): return

	var peer = server_peer.get_peer(id)
	var user = GDTUser.new(id, peer)

	print("New connection from %s ID: %d" % [peer.get_remote_address(), id])

	connected_users.append(user) 

func _disconnected(id: int):
	if not multiplayer.is_server(): return

	var user = get_user_by_id(id)
	assert(user, "User %d disconnected, but was never listed" % id)

	print("User %s (%d) disconnected" % [user.name, id])
	
	var user_dict = user.to_dict()

	auth_rpc(main.client.user_disconnected, [user_dict])
	main.dual.user_disconnected.emit(user)

	connected_users.erase(user)

func create_server_user() -> GDTUser:
	var user = GDTUser.new(1, null)

	user.name = "Server guy :3" # TODO: Get the actual username
	user.type = GDTUser.Type.HOST
	user.id = 1

	user.auth()

	return user

func get_server_user() -> GDTUser:
	for i in connected_users:
		if i.type == GDTUser.Type.HOST:
			return i

	return

func get_authenticated_users(include_server := true) -> Array[GDTUser]:
	var res: Array[GDTUser] = []

	for i in connected_users:
		if i.authenticated and (include_server or i.type != GDTUser.Type.HOST):
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

	multiplayer.multiplayer_peer = server_peer

	connected_users = [
		create_server_user()	
	]

	main.dual.users_listed.emit(connected_users)

	return err

func id_has_permission(peer_id: int, permission: GodotTogether.Permission) -> bool:
	var user = get_user_by_id(peer_id)

	return user != null and user.has_permission(permission)

func get_user_dicts() -> Array[Dictionary]:
	var dicts: Array[Dictionary] = []

	for user in get_authenticated_users():
		dicts.append(user.to_dict())

	return dicts

@rpc("any_peer", "call_remote", "reliable")
func receive_join_data(data_dict: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	var user = get_user_by_id(id)

	print("Receiving data from %d: %s" % [id, data_dict])

	var data = GDTJoinData.from_dict(data_dict)
	var server_password = GDTSettings.get_setting("server/password")
	
	if data.password != server_password:
		print("Invalid password for user %d" % id)
		user.kick(GDTUser.DisconnectReason.PASSWORD_INVALID)
		return

	user.auth()
	user.name = data.username

	print("User %d authenticated as '%s'" % [id, data.username])
	main.client.auth_successful.rpc_id(id)

	var user_dict = user.to_dict()

	main.dual.create_avatar_2d(user_dict)
	main.dual.create_avatar_3d(user_dict)

	auth_rpc(main.client.user_connected, [user_dict], [id])
	main.client.receive_user_list.rpc_id(id, get_user_dicts())
	main.dual.user_connected.emit(user)

	for i in get_authenticated_users():
		if i.id == id: continue
		var dict = i.to_dict()

		main.dual.create_avatar_2d.rpc_id(id, dict)
		main.dual.create_avatar_3d.rpc_id(id, dict)

@rpc("any_peer", "call_remote", "reliable")
func project_files_request(hashes: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	
	print("User %d is requesting the project files" % id)
	
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
func node_update_request(scene_path: String, node_path: NodePath, property_dict: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	
	if not id_has_permission(id, GodotTogether.Permission.EDIT_SCENES): return
	
	main.client.receive_node_updates(scene_path, node_path, property_dict)
	submit_node_update(scene_path, node_path, property_dict, id)

@rpc("any_peer", "call_remote", "reliable")
func node_removal_request(scene_path: String, node_path: NodePath):
	var id = multiplayer.get_remote_sender_id()

	if not id_has_permission(multiplayer.get_remote_sender_id(), GodotTogether.Permission.EDIT_SCENES): return

	submit_node_removal(scene_path, node_path, id)

@rpc("any_peer", "call_remote", "reliable")
func node_add_request(scene_path: String, node_path: NodePath, node_type: String):
	assert(ClassDB.class_exists(node_type))
	
	if not id_has_permission(multiplayer.get_remote_sender_id(), GodotTogether.Permission.EDIT_SCENES): return

	submit_node_add(scene_path, node_path, node_type)

func submit_node_removal(scene_path: String, node_path: NodePath, sender := 0):
	#main.client.receive_node_removal.rpc(scene_path, node_path)
	auth_rpc(main.client.receive_node_removal, [scene_path, node_path], [sender])

func submit_node_update(scene_path: String, node_path: NodePath, property_dict: Dictionary, sender := 0):
	#main.client.receive_node_updates.rpc(scene_path, node_path, property_dict)
	auth_rpc(main.client.receive_node_updates, [scene_path, node_path, property_dict], [sender])

func submit_node_add(scene_path: String, node_path: NodePath, node_type: String, sender := 0):
	#main.client.receive_node_add.rpc(scene_path, node_path, node_type)
	auth_rpc(main.client.receive_node_add, [scene_path, node_path, node_type], [sender])

func auth_rpc(fn: Callable, args: Array, exclude_ids: Array[int] = []):
	for i in get_authenticated_ids(false):
		if not i in exclude_ids:
			fn.rpc_id.callv([i] + args)

func get_user_by_id(id: int) -> GDTUser:
	for i in connected_users:
		if i.id == id:
			return i

	return

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
