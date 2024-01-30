extends Node
class_name GodotTogetherServer

var main:GodotTogether
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


func start_hosting(port:int, max_clients:=10):
	var err = peer.create_server(port, max_clients)
	if err: return err
	multiplayer.multiplayer_peer = peer

@rpc("any_peer", "call_remote", "reliable")
func receive_user_data(data:Dictionary):
	var id = multiplayer.get_remote_sender_id()
	if userdata.has(id): return
	
	var print_data = GodotTogetherSettings.make_editable(data)
	if print_data.has("password"): print_data["password"] = "[ REDACTED ]"
	print("Received data for " + str(id) + ": " + JSON.stringify(print_data))
	
	if not data.has("username"):
		print("Invalid data of "+str(id)+": missing username")
		peer.disconnect_peer(id)
		return
		
	var username_error = GodotTogetherValidator.validate_username(data["username"])
	if username_error:
		print("Invalid username for " + str(id) + GodotTogetherValidator.TextError.find_key(username_error))
		
	var server_password = GodotTogetherSettings.get_setting("server/password")
	if server_password != "":
		if not data.has("password") or data["password"] != server_password:
			print("Access denied for: " + str(id) + ": invalid password")
			peer.disconnect_peer(id)
			return
			
	userdata[id] = {
		"username": data["username"],
		"permission_level": PermissionLevel.EDITOR
	}
	
	print("User " + str(id) + " registered as " + data["username"])
	


func _connected(id: int):
	var connected_peer = peer.get_peer(id)
	print("Peer: "+str(id)+" connected from "+connected_peer.get_remote_address())

	main.create_user_2d(id)
	main.create_user_3d(id)
	
	main.create_user_2d.rpc_id(id, 1)
	main.create_user_3d.rpc_id(id, 1)
	
	for i in multiplayer.get_peers():
		main.create_user_2d.rpc_id(id, i)
		main.create_user_3d.rpc_id(id, i)

func _disconnected(id:int ):
	print("Peer "+str(id)+" disconnected")
