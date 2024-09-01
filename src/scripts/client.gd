extends Node
class_name GodotTogetherClient

var main: GodotTogether
var peer = ENetMultiplayerPeer.new()

var current_data = {}

func _ready():
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.server_disconnected.connect(_disconnected)

func join(ip: String, port: int, data := {}):
	var err = peer.create_client(ip, port)
	if err: return err
	multiplayer.multiplayer_peer = peer
	
	print("Connected, your ID is: " + str(multiplayer.get_unique_id()))
	current_data = data

func is_active() -> bool:
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _connected():
	print("Successfully connected to the server")
	
	await get_tree().physics_frame
	
	main.server.receive_user_data.rpc_id(1, current_data)
	print("Userdata sent")
	
func _disconnected():
	print("Disconnected from server")

@rpc("authority")
func join_successful():
	print("Server accepted connection, requesting files (if needed)")
	
	main.server.project_files_request.rpc_id(1, GodotTogetherFiles.get_file_tree_hashes())

@rpc("authority")
func receive_message(text: String):
	print("[Server message] " + text)

@rpc("authority")
func receive_node_updates(scene_path: String, node_path: NodePath, property_dict: Dictionary):
	var current_scene = main.get_editor_interface().get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not updating.")
		return
	
	var node = current_scene.get_node(node_path)
	if not node: return
	
	for key in property_dict.keys():
		node[key] = property_dict[key]
