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
	if ip == "0:0:0:0:0:0:0:1": return true
	
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
	send_message(id, "Welcome " + data["username"] + "!")


func _connected(id: int):
	if not multiplayer.is_server(): return
	var connected_peer = peer.get_peer(id)
	print("Peer: " + str(id) + " connected from " + connected_peer.get_remote_address())

	await get_tree().create_timer(2).timeout
	
	if not is_authenticated(id):
		print("Authentication timeout for " + str(id))
		peer.disconnect_peer(id)
		return

	main.create_user_2d(id)
	main.create_user_3d(id)
	
	main.create_user_2d.rpc_id(id, 1)
	main.create_user_3d.rpc_id(id, 1)
	
	for i in multiplayer.get_peers():
		if i == id: continue
		main.create_user_2d.rpc_id(id, i)
		main.create_user_3d.rpc_id(id, i)

func _disconnected(id:int ):
	if not multiplayer.is_server(): return
	print("Peer " + str(id) + " disconnected")
	userdata.erase(id)
