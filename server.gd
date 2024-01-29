extends Node
class_name GodotTogetherServer

var peer = ENetMultiplayerPeer.new()

func _ready():
	peer.peer_connected.connect(_connected)
	peer.peer_disconnected.connect(_disconnected)


func start_hosting(port:int, max_clients:=10):
	var err = peer.create_server(port, max_clients)
	if err: return err
	multiplayer.multiplayer_peer = peer

func _connected(id: int):
	var peer = peer.get_peer(id)
	print("Peer: "+str(id)+" connected from "+peer.get_remote_address())

func _disconnected(id:int ):
	print("Peer "+str(id)+" disconnected")
