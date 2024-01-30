extends Node
class_name GodotTogetherClient

var main:GodotTogether
var peer = ENetMultiplayerPeer.new()

var current_data = {}

func _ready():
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.server_disconnected.connect(_disconnected)

func join(ip:String, port:int, data := {}):
	var err = peer.create_client(ip, port)
	if err: return err
	multiplayer.multiplayer_peer = peer
	
	print("Connected, your ID is: "+str(multiplayer.get_unique_id()))
	current_data = data


func _connected():
	print("Successfully connected to the server")
	main.server.receive_user_data.rpc_id(1, current_data)
	print("Userdata sent")
	
func _disconnected():
	print("Disconnected from server")

@rpc("authority")
func receive_message(text:String):
	print("[Server message] " + text)
