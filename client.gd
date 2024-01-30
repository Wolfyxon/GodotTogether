extends Node
class_name GodotTogetherClient

var main:GodotTogether
var peer = ENetMultiplayerPeer.new()

func join(ip:String, port:int, data := {}):
	var err = peer.create_client(ip, port)
	if err: return err
	multiplayer.multiplayer_peer = peer
	
	print("Connected, your ID is: "+str(multiplayer.get_unique_id()))
	main.server.receive_user_data.rpc_id(1, data)
	print("Userdata sent")
