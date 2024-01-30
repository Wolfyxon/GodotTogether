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

func _ready():
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)


func start_hosting(port:int, max_clients:=10):
	var err = peer.create_server(port, max_clients)
	if err: return err
	multiplayer.multiplayer_peer = peer

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
