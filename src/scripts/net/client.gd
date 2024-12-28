@tool
extends GodotTogetherComponent
class_name GodotTogetherClient

var client_peer = ENetMultiplayerPeer.new()
var current_join_data := GodotTogetherJoinData.new()

func _ready():
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.server_disconnected.connect(_disconnected)

func _connected():
	if multiplayer.is_server(): return

	print("Connection successful")

	await get_tree().physics_frame
	main.server.receive_join_data.rpc_id(1, current_join_data.as_dict())

func _disconnected():
	if multiplayer.is_server(): return

@rpc("authority")
func auth_successful():
	print("Server accepted connection, requesting files (if needed)")
	
	main.server.project_files_request.rpc_id(1, GodotTogetherFiles.get_file_tree_hashes())

@rpc("authority", "reliable")
func receive_file(path: String, buffer: PackedByteArray):
	if not GodotTogetherValidator.is_path_safe(path):
		print("Server attempted to send file at unsafe location: " + path)
		return
	
	print("Downloading " + path)
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	var err = FileAccess.get_open_error()

	assert(err == OK, "Failed to open %s: %i" % [path, err])
	
	f.store_buffer(buffer)
	
	print("Saved successfully")
	
	if path.get_extension() == "tscn":
		EditorInterface.reload_scene_from_path(path)

func is_active() -> bool:
	return client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
