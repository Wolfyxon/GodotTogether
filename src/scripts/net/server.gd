@tool
extends GodotTogetherComponent
class_name GodotTogetherServer

const LOCALHOST := [
	"0:0:0:0:0:0:0:1", 
	"127.0.0.1", 
	":1", 
	"localhost"
]

var server_peer = ENetMultiplayerPeer.new()
var connected_users: Array[GodotTogetherUser] = []

func _ready():
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)

func _connected(id: int):
	if not multiplayer.is_server(): return

	var peer = server_peer.get_peer(id)
	var user = GodotTogetherUser.new(id, peer)

	connected_users.append(user) 

func _disconnected(id: int):
	if not multiplayer.is_server(): return

	var user = get_user_by_id(id)
	assert(user, "User %i disconnected, but was never listed" % id)

	connected_users.erase(user)

@rpc("any_peer", "call_remote", "reliable")
func receive_join_data(data_dict: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	var user = get_user_by_id(id)

	print("Receiving data from %i: %s" % [id, data_dict])

	var data = GodotTogetherJoinData.from_dict(data_dict)
	var server_password = GodotTogetherSettings.get_setting("server/password")
	
	if data.password != server_password:
		print("Invalid password for user %i" % id)
		user.kick()
		return

	user.authenticated = true
	user.username = data.username

	print("User %i authenticated as '%s'" % [id, data.username])
	main.client.auth_successful.rpc_id(id)

@rpc("any_peer", "call_remote", "reliable")
func project_files_request(hashes: Dictionary):
	var id = multiplayer.get_remote_sender_id()
	
	print("User %i is requesting the project files" % id)
	
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

func submit_node_update(scene_path: String, node_path: NodePath, property_dict: Dictionary):
	main.client.receive_node_updates.rpc(scene_path, node_path, property_dict)
	main.client.receive_node_updates(scene_path, node_path, property_dict)

func get_user_by_id(id: int) -> GodotTogetherUser:
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
	var c = int(split[2])
	var d = int(split[3])
	
	if a == 127: return true
	if a == 172 and b >= 16 and b <= 31: return true
	if a == 192 and b == 168: return true
	
	return false