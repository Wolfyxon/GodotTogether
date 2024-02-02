extends Node
## Class for managing session logic that runs on both server and client
class_name GodotTogetherDual

var main:GodotTogether
var camera:Camera3D
var update_timer = Timer.new()
var scan_timer = Timer.new()

var prev_mouse_pos := Vector2()
var prev_3d_pos := Vector3()
var prev_3d_rot := Vector3()

func _ready():
	if not main: return
	camera = main.get_editor_3d_camera()
	
	multiplayer.peer_connected.connect(_connected)
	multiplayer.peer_disconnected.connect(_disconnected)

	update_timer.timeout.connect(_update)
	update_timer.one_shot = false
	update_timer.wait_time = 0.02
	add_child(update_timer)
	update_timer.start()
	
	scan_timer.timeout.connect(_scan)
	scan_timer.one_shot = false
	scan_timer.wait_time = 0.03
	add_child(scan_timer)
	scan_timer.start()

func _scan():
	pass

func _update():
	if not main: return
	if not main.is_session_active(): return
	
	var mPos = EditorInterface.get_editor_viewport_2d().get_mouse_position() / Vector2(EditorInterface.get_editor_viewport_2d().size)
	if mPos != prev_mouse_pos and DisplayServer.window_is_focused():
		prev_mouse_pos = mPos
		update_2d_marker.rpc(mPos)
		
	if camera.position != prev_3d_pos or camera.rotation != prev_3d_rot:
		prev_3d_pos = camera.position
		prev_3d_rot = camera.rotation
		
		update_3d_marker.rpc(camera.position, camera.rotation)

func _connected(id:int):
	pass
	
func _disconnected(id:int):
	var marker3d = main.get_user_3d(id)
	var marker2d = main.get_user_2d(id)
	
	if marker2d: 
		marker2d.queue_free()
		main.user_2d_markers.erase(marker2d)
	if marker3d: 
		marker3d.queue_free()
		main.user_3d_markers.erase(marker3d)
	

@rpc("any_peer")
func update_2d_marker(vector: Vector2):
	if not main: return
	var marker = main.get_user_2d(multiplayer.get_remote_sender_id())
	if not marker: return
	marker.set_position_percent(vector)

@rpc("any_peer")
func update_3d_marker(position:Vector3, rotation:Vector3):
	if not main: return
	var marker = main.get_user_3d(multiplayer.get_remote_sender_id())
	if not marker: return
	marker.position = position
	marker.rotation = rotation

