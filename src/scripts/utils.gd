@tool
class_name GDTUtils

const DICT_PATH_SEPARATOR = "/"

static func sha256_of_buffer(buffer: PackedByteArray) -> String:
	var hasher = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(buffer)
	
	return hasher.finish().hex_encode()

static func alphabetic_dict_hash(dict: Dictionary) -> int:
	var keys = dict.keys()
	keys.sort()
	
	var res = 0
	
	for key in keys:
		res += hash(dict[key])
	
	return res

static func get_rpc_checksum(node: Node) -> int:
	var script: Script = node.get_script()
	var res = 0
	
	if script:
		var script_conf: Dictionary = script.get_rpc_config()
		
		if script_conf:
			res += alphabetic_dict_hash(script_conf)
	
	var node_conf = node.get_node_rpc_config()
	
	if node_conf:
		res += alphabetic_dict_hash(node_conf)
	
	return res 

static func get_rpc_checksum_recursive(root: Node, max_depth := 8) -> int:
	var res = get_rpc_checksum(root)
	
	if max_depth > 1:
		var children = root.get_children()
		children.sort()
		
		for i in children:
			var sub_hash = get_rpc_checksum_recursive(i, max_depth - 1)
			res = hash(res + hash(sub_hash))
	
	return res

static func join(array: Array, separator := "\n") -> String:
	var res = ""
	var ln = array.size()
	
	for i in ln:
		res += str(array[i])
		
		if i != ln - 1:
			res += separator
	
	return res

static func avg(array: Array) -> float:
	var sum: float = 0.0
	
	for i in array:
		sum += float(i)
	
	return sum / float(array.size())

static func has_readonly(dict: Dictionary) -> bool:
	if dict.is_read_only():
		return true
	
	for val in dict.values():
		if typeof(val) == TYPE_DICTIONARY and has_readonly(val):
			return true
	
	return false

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	for key in b.keys():
		if not key in a:
			a[key] = b[key]

		if (a[key] is Dictionary) and (b[key] is Dictionary):
			a[key] = merge(a[key], b[key])

	return a

static func get_nested(obj, path: String, separator := DICT_PATH_SEPARATOR):
	var levels = path.split(separator)
	var current = obj
	
	for level in levels:
		if not current is Dictionary and not current is Object:
			return
		
		if not level in current: 
			return
		
		current = current[level]
	
	return current
	
static func has_nested(obj, path: String, separator := DICT_PATH_SEPARATOR) -> bool:
	var levels = path.split(separator)
	var current = obj
	
	for level in levels:
		if not current is Dictionary and not current is Object:
			return false
		
		if not level in current: 
			return false
		
		current = current[level]
	
	return true

static func erase_nested(dict: Dictionary, path: String, separator := DICT_PATH_SEPARATOR) -> bool:
	var levels = path.split(separator)
	var current = dict
	
	for level_i in levels.size():
		var level = levels[level_i]
		
		if not current is Dictionary:
			return false
		
		if not level in current: 
			return false
		
		if level_i == levels.size() - 1:
			current.erase(level)
		else:
			current = current[level]
	
	return true

static func set_nested(
	obj, 
	path: String, 
	value, 
	separator := DICT_PATH_SEPARATOR
) -> bool:
	if obj is Dictionary:
		assert(not obj.is_read_only(), "Dictionary is read only")
	
	var levels = path.split(separator)
	var current = obj

	for i in range(levels.size() - 1):
		var level = levels[i]
		
		if not current is Dictionary and not current is Object:
			return false
		
		if not level in current:
			if current is Dictionary:
				current[level] = {}
			elif current is Object:
				return false
		
		#if current is Dictionary and not level in current:
			#current[level] = {}
		#elif current is Object and not level in current:
			#return
		
		current = current[level]
	
	if not current:
		return false
	
	if not levels[-1]:
		return false
	
	current[levels[-1]] = value
	return true

static func append_array_prefixed(array: Array, new_values: Array, prefix: String) -> void:
	for i in new_values:
		array.append(prefix + i)

static func compare_dicts(
	a: Dictionary, 
	b: Dictionary, 
	separator := DICT_PATH_SEPARATOR, 
	depth := 16
) -> Array:
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
			
		if depth > 0 and typeof(val_a) == TYPE_DICTIONARY and typeof(val_b) == TYPE_DICTIONARY:
			var sub_changes = compare_dicts(val_a, val_b, separator, depth - 1)
			append_array_prefixed(changed_paths, sub_changes, key + separator)
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

static func try_connect(sig: Signal, fn: Callable) -> void:
	if not sig.is_connected(fn):
		sig.connect(fn)

static func try_connect_bulk(dict: Dictionary) -> void:
	for sig in dict.keys():
		var fn = dict[sig]
		
		if typeof(sig) != TYPE_SIGNAL:
			printerr_stack("Expected Signal, got %s for key %s" % [type_string(typeof(sig)), sig])
			continue
			
		if typeof(fn) != TYPE_CALLABLE:
			printerr_stack("Expected Callable, got %s for value at key %s" % [type_string(typeof(fn)), sig])
			continue
		
		try_connect(sig, fn)

static func try_open_scene(scene_path: String, tries := 100) -> void:
	if not scene_path:
		return
	
	var tree = get_tree()

	for i in tries:
		var f = FileAccess.open(scene_path, FileAccess.READ)
		
		if not f:
			await tree.create_timer(0.1).timeout
		else:
			f.close()
			EditorInterface.open_scene_from_path(scene_path)
			break

static func close_all_scenes() -> void:
	var tree = get_tree()
	
	while EditorInterface.get_edited_scene_root():
		EditorInterface.close_scene()
		await tree.process_frame

static func get_loaded_scene_root(path: String) -> Node:
	for i in EditorInterface.get_open_scene_roots():
		if i.scene_file_path == path:
			return i

	return null

static func get_node_in_scene(node_path: String, scene_path: String) -> Node:
	for scene in EditorInterface.get_open_scene_roots():
		if scene.scene_file_path == scene_path:
			return scene.get_node_or_null(node_path)
	
	return

static func get_node_scene(node: Node) -> Node:
	if node.owner:
		return node.owner
	
	if node.scene_file_path:
		return node
	
	return

static func get_descendants(node: Node, include_internal := false) -> Array[Node]:
	var res: Array[Node] = []
	
	for i in node.get_children(include_internal):
		if i.get_child_count(include_internal) != 0: res.append_array(get_descendants(i, include_internal))
		res.append(i)
	
	return res

static func get_descendant_with_class(root: Node, search_class: String) -> Node:
	for i in root.get_children():
		if i.get_class() == search_class:
			return i
			
		var sub = get_descendant_with_class(i, search_class)
		
		if sub:
			return sub
	
	return

static func get_descendants_with_class(root: Node, search_class: String) -> Array:
	var res = []
	
	for i in root.get_children():
		if i and i.is_class(search_class):
			res.append(i)
			
		var sub = get_descendants_with_class(i, search_class)
		
		if sub:
			res.append_array(sub)
	
	return res

static func is_peer_connected(peer: MultiplayerPeer) -> bool:
	return peer.get_connection_status() == peer.CONNECTION_CONNECTED

static func set_control_value(node: Control, value, format := "") -> void:
	node.set_block_signals(true)
	
	if node is OptionButton:
		var idx = node.get_item_index(value)
		node.select(idx)
	elif node is Button:
		if not value is bool:
			printerr("value must be bool. %s: %s" % [node.get_path(), value])
			print_stack()
			return
		
		if not node.toggle_mode:
			push_error("Button %s must have toggle_mode enabled" % node.name)
		
		node.set_pressed_no_signal(value)
	elif node is SpinBox:
		node.set_value_no_signal(value)
	elif node is LineEdit:
		node.text = value
	elif node is Label:
		const DATE_PLACEHOLDER = "<date>"
		
		if format and format.contains(DATE_PLACEHOLDER):
			var tm = Time.get_date_string_from_unix_time(value)
			node.text = format.replace(DATE_PLACEHOLDER, tm)
		else:
			node.text = str(value)
	else:
		push_error("Unsupported control type %s '%s'" % [node.get_class(), node.name])
	
	node.set_block_signals(false)

static func set_control_disabled(node: Control, state: bool) -> void:
	if node is Button:
		node.disabled = state
	elif node is TextEdit or node is LineEdit or node is SpinBox:
		node.editable = not state
	else:
		printerr_stack("Unsupported class %s %s" % [node.get_class(), node])

static func is_file_resource(resource: Resource) -> bool:
	return not resource.resource_path.is_empty() and not resource.resource_path.contains("::")

static func line_column_to_index(text: String, line: int, col: int) -> int:
	var lines = text.split("\n")
	
	if lines.size() <= line:
		return -1
	
	var res = 0
	
	for line_i in lines.size():
		if line_i != line:
			res += lines[line_i].length() + 1 # 1 for \n char
		else:
			res += col
			break
	
	return res

static func index_to_line_column(text: String, idx: int) -> Array:
	if idx < 0:
		return [-1, -1]
	
	if idx >= text.length():
		return [-1, -1]
	
	var line = 0
	var col = 0
	
	var cols_counted = false
	
	for i in idx:
		var ch = text[i]
		var ch_reverse = text[idx - i - 1]
		
		if ch == "\n":
			line += 1
		
		if ch_reverse == "\n":
			cols_counted = true
		
		if not cols_counted:
			col += 1
		
	return [line, col]
		
static func get_stack_lines() -> Array:
	var res = []
	var stack = get_stack()
	
	stack.remove_at(0)
	
	for i in stack:
		res.append("%s %s:%s" % [ i["source"], i["function"], i["line"] ])
	
	return res

static func get_engine_version_str() -> String:
	var ver_info = Engine.get_version_info()
	
	return "%s.%s.%s-%s" % [
		ver_info["major"],
		ver_info["minor"],
		ver_info["patch"],
		ver_info["status"]
	]

static func printerr_stack(message) -> void:
	var stack_lines = get_stack_lines()
	stack_lines.remove_at(0)
	
	printerr(message, "\n-- Traceback: --\n", GDTUtils.join(stack_lines, "\n"), "\n-----------")
