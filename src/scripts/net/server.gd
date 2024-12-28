extends Node
class_name GodotTogetherServer

var main: GodotTogether
var peer = ENetMultiplayerPeer.new()

enum PermissionLevel {
	GUEST, # only view access
	EDITOR, # can edit the project
	ADMIN, # can kick other users
	HOST # full access, not assignable
}
var userdata = {
#	id: {
#		username: "",
#		permission_level: PermissionLevel.EDITOR,
#	}
}

func _ready():
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)


static func is_local(ip: String) -> bool:
	if ip in ["0:0:0:0:0:0:0:1", "127.0.0.1", ":1", "localhost"]: return true
	
	var split = ip.split(".")
	if split.size() != 4:
		push_error(ip + " doesn't seem to be a valid IP address: size not equal to 4. Assuming this is not a local address.")
		return false
	
	var a = int(split[0])
	var b = int(split[1])
	var c = int(split[2])
	var d = int(split[3])
	
	if a == 127: return true
	if a == 172 and b >= 16 and b <= 31: return true
	if a == 192 and b == 168: return true
	
	return false

func start_hosting(port: int, max_clients := 10):
	var err = peer.create_server(port, max_clients)
	if err: return err
	multiplayer.multiplayer_peer = peer

func is_active() -> bool:
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func is_authenticated(peerId:int):
	return userdata.has(peerId)

func send_message(peerId: int, text: String):
	main.client.receive_message.rpc_id(peerId, text)

@rpc("any_peer", "call_remote", "reliable")
func receive_user_data(data: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	if userdata.has(id): return
	
	var print_data = GodotTogetherSettings.make_editable(data)
	if print_data.has("password"): print_data["password"] = "[ REDACTED ]"
	print("Received data for " + str(id) + ": " + JSON.stringify(print_data))
	
	if not data.has("username"):
		print("Invalid data of " + str(id) + ": missing username")
		send_message(id,"Invalid data, missing username")
		peer.disconnect_peer(id)
		return
		
	var username_error = GodotTogetherValidator.validate_username(data["username"])
	if username_error:
		var err_name = GodotTogetherValidator.TextError.find_key(username_error)
		print("Invalid username for " + str(id) + err_name)
		send_message(id,"Your username is invalid: " + err_name)
		peer.disconnect_peer(id)
		return
		
	var server_password = GodotTogetherSettings.get_setting("server/password")
	if server_password != "":
		if not data.has("password") or data["password"] != server_password:
			print("Access denied for: " + str(id) + ": invalid password")
			send_message(id, "Access denied, invalid password")
			peer.disconnect_peer(id)
			return
			
	userdata[id] = {
		"username": data["username"],
		"permission_level": PermissionLevel.EDITOR
	}
	
	print("User " + str(id) + " registered as " + data["username"])
	
	main.client.join_successful.rpc_id(id)
	send_message(id, "Welcome " + data["username"] + "!")

@rpc("any_peer", "call_remote", "reliable")
func project_files_request(hashes: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	
	print("User " + str(id) + " is requesting the project files")
	
	var local_hashes = GodotTogetherFiles.get_file_tree_hashes()
	
	if hash(hashes) != hash(local_hashes):
		print("User's project files don't match, sending")
		
		for path in local_hashes.keys():
			var local_hash = local_hashes[path]
			
			
			if not hashes.has(path) or local_hash != hashes[path]:
				var buf = FileAccess.get_file_as_bytes(path)
				if not buf: continue
				
				print("Sending " + path)
				main.client.receive_file.rpc_id(id, path, buf)
		
	else:
		print("User's project files match, not sending")

@rpc("any_peer", "call_remote", "reliable")
func node_update_request(scene_path: String, node_path: NodePath, property_dict: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	var user = userdata[id]
	if not user: return
	if user["permission_level"] < PermissionLevel.EDITOR: return
	
	submit_node_update(scene_path, node_path, property_dict)

func submit_node_update(scene_path: String, node_path: NodePath, property_dict: Dictionary):
	main.client.receive_node_updates.rpc(scene_path, node_path, property_dict)
	main.client.receive_node_updates(scene_path, node_path, property_dict)

func _connected(id: int):
	if not multiplayer.is_server(): return
	var connected_peer = peer.get_peer(id)
	print("Peer: " + str(id) + " connected from " + connected_peer.get_remote_address())

	await get_tree().create_timer(2).timeout
	
	if not is_authenticated(id):
		print("Authentication timeout for " + str(id))
		peer.disconnect_peer(id)
		return

	main.dual.create_user_2d(id)
	main.dual.create_user_3d(id)
	
	main.dual.create_user_2d.rpc_id(id, 1)
	main.dual.create_user_3d.rpc_id(id, 1)
	
	for i in multiplayer.get_peers():
		if i == id: continue
		main.dual.create_user_2d.rpc_id(id, i)
		main.dual.create_user_3d.rpc_id(id, i)

func _disconnected(id:int ):
	if not multiplayer.is_server(): return
	print("Peer " + str(id) + " disconnected")
	userdata.erase(id)
