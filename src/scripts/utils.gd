@tool
class_name GDTUtils

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

static func make_editable(dict: Dictionary) -> Dictionary:
	if not dict.is_read_only(): 
		return dict
	
	return dict.duplicate(true)

static func get_nested(dict: Dictionary, path:String, separator := "/"):
	var levels = path.split(separator)
	var current = dict
	
	for level in levels:
		if not current.has(level): return
		current = current[level]
	
	return current

static func set_nested(dict: Dictionary, path: String, value, separator:= "/") -> void:
	assert(not dict.is_read_only(), "Dictionary is read only")
	
	var levels = path.split(separator)
	var current = dict

	for i in range(levels.size() - 1):
		var level = levels[i]
		if not current.has(level):
			current[level] = {}
		
		current = current[level]

	current[levels[-1]] = value

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
