extends Node
## Class for managing session logic that runs on both server and client
class_name GodotTogetherDual

var main:GodotTogether
var update_timer = Timer.new()

var prev_mouse_pos := Vector2()

func _ready():
	if not main: return
	
	main.client.peer.peer_connected.connect(_connected)
	main.client.peer.peer_disconnected.connect(_disconnected)
	
	main.server.peer.peer_connected.connect(_connected)
	main.server.peer.peer_disconnected.connect(_disconnected)
	
	update_timer.timeout.connect(_update)
	update_timer.one_shot = false
	update_timer.wait_time = 0.02
	add_child(update_timer)
	update_timer.start()

func _update():
	if not main: return
	if not main.is_session_active(): return
	
	var mPos = get_viewport().get_mouse_position()
	if mPos != prev_mouse_pos:
		prev_mouse_pos = mPos
		rpc("update_2d_marker", mPos)

func _connected(id:int):
	pass
	
func _disconnected(id:int):
	pass

@rpc("any_peer")
func update_2d_marker(vector: Vector2):
	if not main: return
	main.get_user_2d(multiplayer.get_remote_sender_id()).set_position_percent(vector)
