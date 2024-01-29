extends Node
class_name GodotTogetherClient

var peer = ENetMultiplayerPeer.new()

func join(ip:String, port:int):
	var err = peer.create_client(ip, port)
	if err: return err
	multiplayer.multiplayer_peer = peer
