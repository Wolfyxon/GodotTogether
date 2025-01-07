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

	print("Disconnected from server")

func join(ip: String, port: int, data := GodotTogetherJoinData.new()) -> int:
	var err = client_peer.create_client(ip, port)
	if err: return err

	multiplayer.multiplayer_peer = client_peer
	
	print("Connected, your ID is: " + str(multiplayer.get_unique_id()))
	current_join_data = data

	return OK

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

@rpc("authority", "call_local")
func receive_node_updates(scene_path: String, node_path: NodePath, property_dict: Dictionary):
	var current_scene = EditorInterface.get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not updating.")
		return
	
	var node = current_scene.get_node(node_path)
	if not node: return
	
	for key in property_dict.keys():
		node[key] = property_dict[key]

@rpc("authority", "call_local")
func receive_node_removal(scene_path: String, node_path: NodePath):
	var current_scene = EditorInterface.get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not removing.")
		return

	var node = current_scene.get_node(node_path)
	if not node: return

	prints("rm", node_path)
	node.queue_free()

var fuse = 0

@rpc("authority", "call_remote")
func receive_node_add(scene_path: String, node_path: NodePath, node_type: String):
	assert(fuse < 10, "NODE OVERFLOW (temporary safety measure)")
	fuse += 1

	var current_scene = EditorInterface.get_edited_scene_root()
	
	if not current_scene or current_scene.scene_file_path != scene_path:
		print("NOT IMPLEMENTED YET. Node outside of current scene, not adding.")
		return

	var existing = current_scene.get_node_or_null(node_path)
	var path_size = node_path.get_name_count()
	
	var parent_path = node_path.slice(0, path_size - 1)
	var parent: Node = current_scene.get_node_or_null(parent_path)

	if parent_path.is_empty():
		parent = current_scene

	if existing:
		print(existing)
		print(parent.get_children())
		assert(false, "Node %s already exists, not adding" % node_path)

	assert(parent, "Node add failed: Parent (%s) not found for (%s)" % [parent_path, node_path])
	
	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_path.get_name(path_size - 1)

	main.change_detector.suppress_add_signal(scene_path, node_path)
	
	await get_tree().process_frame

	parent.add_child(node)
	node.owner = current_scene

func is_active() -> bool:
	return client_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
