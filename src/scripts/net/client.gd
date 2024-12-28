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

func join(ip: String, port: int, data := GodotTogetherJoinData.new()):
	var err = client_peer.create_client(ip, port)
	if err: return err

	multiplayer.multiplayer_peer = client_peer
	
	print("Connected, your ID is: " + str(multiplayer.get_unique_id()))
	current_join_data = data

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

	assert(err == OK, "Failed to open %s: %d" % [path, err])
	
	f.store_buffer(buffer)
	
	print("Saved successfully")
	
	if path.get_extension() == "tscn":
		EditorInterface.reload_scene_from_path(path)

@rpc("authority")
func receive_node_updates(scene_path: String, node_path: NodePath, property_dict: Dictionary):
	var current_scene = EditorInterface.get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not updating.")
		return
	
	var node = current_scene.get_node(node_path)
	if not node: return
	
	for key in property_dict.keys():
		node[key] = property_dict[key]

func is_active() -> bool:
	return client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
