@tool
class_name GDTUtils

const DICT_PATH_SEPARATOR = "/"

static func sha256_of_buffer(buffer: PackedByteArray) -> String:
	var hasher = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(buffer)
	
	return hasher.finish().hex_encode()

static func sha256_of_file(path: String) -> String:
	var hasher = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		printerr("Unable to hash file at %s" % path)
		return ""
	
	var file_len = file.get_length()
	
	while file.get_position() < file_len:
		var rem = file.get_length() - file.get_position()
		hasher.update(file.get_buffer(min(128, rem)))
	
	
	return hasher.finish().hex_encode()

static func join(array: Array, separator := "\n") -> String:
	var res = ""
	var ln = array.size()
	
	for i in ln:
		res += str(array[i])
		
		if i != ln - 1:
			res += separator
	
	return res

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	for key in b.keys():
		if not key in a:
			a[key] = b[key]

		if (a[key] is Dictionary) and (b[key] is Dictionary):
			a[key] = merge(a[key], b[key])

	return a

static func get_nested(dict: Dictionary, path:String, separator := DICT_PATH_SEPARATOR):
	var levels = path.split(separator)
	var current = dict
	
	for level in levels:
		if not current.has(level): return
		current = current[level]
	
	return current

static func set_nested(dict: Dictionary, path: String, value, separator := DICT_PATH_SEPARATOR) -> void:
	assert(not dict.is_read_only(), "Dictionary is read only")
	
	var levels = path.split(separator)
	var current = dict

	for i in range(levels.size() - 1):
		var level = levels[i]
		if not current.has(level):
			current[level] = {}
		
		current = current[level]

	current[levels[-1]] = value

static func append_array_prefixed(array: Array, new_values: Array, prefix: String) -> void:
	for i in new_values:
		array.append(prefix + i)

static func compare_dicts(a: Dictionary, b: Dictionary, depth := 16) -> Array:
	var changed_paths = []
	
	for key in a.keys():
		if not key in b:
			changed_paths.append(key)
			continue
		
		var val_a = a[key]
		var val_b = b[key]
		
		if typeof(val_a) != typeof(val_b):
			changed_paths.append(key)
			continue
			
		if val_a is Dictionary and val_b is Dictionary and depth > 0:
			var sub_changes = compare_dicts(val_a, val_b, depth - 1)
			append_array_prefixed(changed_paths, sub_changes, key + DICT_PATH_SEPARATOR)
			continue
		
		if val_a != val_b:
			changed_paths.append(key)
	
	for key in b.keys():
		if not key in a:
			changed_paths.append(key)
			continue
	
	return changed_paths

static func get_tree() -> SceneTree:
	return EditorInterface.get_base_control().get_tree()

static func try_open_scene(scene_path: String, tries := 100) -> void:
	var tree = get_tree()

	for i in 100:
		var f = FileAccess.open(scene_path, FileAccess.READ)
		
		if not f:
			await tree.create_timer(0.1).timeout
		else:
			f.close()

			EditorInterface.open_scene_from_path(scene_path)

			break

static func close_all_scenes() -> void:
	var scene = EditorInterface.get_edited_scene_root()
	var tree = get_tree()
	
	while EditorInterface.get_edited_scene_root():
		EditorInterface.close_scene()
		await tree.process_frame

static func get_loaded_scene_root(path: String) -> Node:
	for i in EditorInterface.get_open_scene_roots():
		if i.scene_file_path == path:
			return i

	return null

static func get_descendants(node: Node, include_internal := false) -> Array[Node]:
	var res: Array[Node] = []
	
	for i in node.get_children(include_internal):
		if i.get_child_count(include_internal) != 0: res.append_array(get_descendants(i, include_internal))
		res.append(i)
	
	return res
	
static func is_peer_connected(peer: MultiplayerPeer) -> bool:
	return peer.get_connection_status() == peer.CONNECTION_CONNECTED

static func set_control_value(node: Control, value) -> void:
	node.set_block_signals(true)
	
	if node is OptionButton:
		var idx = node.get_item_index(value)
		node.select(idx)
	elif node is Button:
		if not node.toggle_mode:
			push_error("Button %s must have toggle_mode enabled" % node.name)
		
		node.set_pressed_no_signal(value)
	elif node is SpinBox:
		node.set_value_no_signal(value)
	elif node is LineEdit:
		node.text = value
	elif node is Label:
		const VALUE_PLACEHHOLDER = "<value>"
		# TODO: time placeholder
		if node.text.contains(VALUE_PLACEHHOLDER):
			node.text = node.text.replace(VALUE_PLACEHHOLDER, str(value))
		else:
			node.text = str(value)
	else:
		push_error("Unsupported control type %s '%s'" % [node.get_class(), node.name])
	
	node.set_block_signals(false)

static func is_file_resource(resource: Resource) -> bool:
	return not resource.resource_path.is_empty() and not resource.resource_path.contains("::")
	
