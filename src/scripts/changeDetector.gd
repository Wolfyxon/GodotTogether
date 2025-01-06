@tool
extends GodotTogetherComponent
class_name GodotTogetherChangeDetector

signal scene_changed
signal node_properties_changed(node: Node, changed_keys: Array)
#signal node_property_changed(node: Node, key: String)
#signal node_property_differs(node: Node, key: String, old_value, new_value)
signal node_removed(node: Node)
signal node_added(node: Node)

const IGNORED_PROPERTY_USAGE_FLAGS = [
	PROPERTY_USAGE_GROUP, 
	PROPERTY_USAGE_CATEGORY, 
	PROPERTY_USAGE_SUBGROUP
]

var observed_nodes = {}
var observed_nodes_cache = {}
var incoming_nodes = {
	# scene path: Array[NodePath]
}

var last_scene := ""

static func get_property_keys(node: Node) -> Array[String]:
	var res: Array[String] = []
	
	for i in node.get_property_list():
		var con = true
		
		for usage in IGNORED_PROPERTY_USAGE_FLAGS:
			if i.usage & usage:
				con = false
				break
			
		if not con: continue
		res.append(i.name)
		
	return res

static func get_property_dict(node: Node) -> Dictionary:
	var res = {}
	
	for i in get_property_keys(node):
		res[i] = node[i]
	
	return res

func _process(_delta):
	if not main: return
	
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	
	var current_scene_path = root.scene_file_path
	if last_scene != current_scene_path:
		last_scene = current_scene_path
		scene_changed.emit()
	
	for node in observed_nodes:
		if not is_instance_valid(node):
			continue # Freed nodes are automatically erased from arrays
		
		if not node.is_inside_tree():
			observed_nodes.erase(node) 
			continue
		
		var cached = observed_nodes_cache[node]
		var current = get_property_dict(node)
		
		var changed_keys = []
		
		for i in current.keys():
			if cached[i] != current[i]:
				#node_property_changed.emit(node, i)
				#node_property_differs.emit(node, i, cached[i], current[i])
				changed_keys.append(i)
				
		if changed_keys.size() != 0:
			node_properties_changed.emit(node, changed_keys)
			observed_nodes_cache[node] = current

func _node_added(node: Node):
	var current_scene = EditorInterface.get_edited_scene_root()
	
	if current_scene.scene_file_path in incoming_nodes:
		var incoming = incoming_nodes[current_scene.scene_file_path]

		if node.get_path_to(current_scene) in incoming:
			return

	node_added.emit(node)

func get_observed_nodes() -> Array[Node]:
	var res: Array[Node]

	for i in observed_nodes.keys():
		res.append(i)

	return res

func suppress_add_signal(scene_path: String, node_path: NodePath):
	if not scene_path in incoming_nodes:
		incoming_nodes[scene_path] = []

	incoming_nodes[scene_path].append(node_path)

func observe(node: Node):
	if node in observed_nodes: return

	observed_nodes_cache[node] = get_property_dict(node)
	observed_nodes[node] = {}

	node.tree_exiting.connect(node_removed.emit.bind(node))
	
	# property_list_changed doesn't fire in editor
	#var cache = get_property_dict(node)
	#
	#var on_change = func():
		#var changed_keys = []
		#var current = get_property_dict(node)
		#
		#for i in current.keys():
			#if cache[i] != current[i]:
				#node_property_changed.emit(node, i)
				#node_property_differs.emit(node, i, cache[i], current[i])
				#changed_keys.append(i)
		#
		#node_properties_changed.emit(node, changed_keys)
		#cache = current
	#
	#node.property_list_changed.connect(on_change)
	#node.tree_exiting.connect(func():
		#node.property_list_changed.disconnect(on_change)
	#)

func observe_recursive(node: Node):
	observe(node)
	
	for i in GodotTogetherUtils.get_descendants(node):
		observe(i)
