@tool
extends Node
class_name GodotTogetherServer

const LOCALHOST := [
	"0:0:0:0:0:0:0:1", 
	"127.0.0.1", 
	":1", 
	"localhost"
]

var main: GodotTogether
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