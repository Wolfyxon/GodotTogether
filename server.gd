extends Node
class_name GodotTogetherServer

var peer = ENetMultiplayerPeer.new()

func start_hosting(port:int, max_clients:=10):
	var err = peer.create_server(port, max_clients)
	if err: return err
	multiplayer.multiplayer_peer = peer
