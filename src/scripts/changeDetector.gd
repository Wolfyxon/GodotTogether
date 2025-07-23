@tool
extends GDTComponent
class_name GDTChangeDetector

signal scene_changed
signal node_properties_changed(node: Node, changed_keys: Array)
#signal node_property_changed(node: Node, key: String)
signal node_removed(node: Node)
signal node_added(node: Node)

const IGNORED_PROPERTY_USAGE_FLAGS := [
	PROPERTY_USAGE_NONE,
	PROPERTY_USAGE_GROUP, 
	PROPERTY_USAGE_CATEGORY, 
	PROPERTY_USAGE_SUBGROUP,
	PROPERTY_USAGE_INTERNAL,
	PROPERTY_USAGE_READ_ONLY
]
const REFRESH_RATE: float = 0.1

# Dicts are faster than arrays apparently
var observed_nodes := {}
var supressed_nodes := {}

var observed_nodes_cache := {}
var incoming_nodes := {
	# scene path: Array[NodePath]
}
var refrate: Timer = Timer.new()

var last_scene := ""

static func get_property_keys(obj: Object) -> Array[String]:
	var res: Array[String] = []
	
	for i in obj.get_property_list():
		var con := true
		
		for usage in IGNORED_PROPERTY_USAGE_FLAGS:
			if i.usage & usage:
				con = false
				break
			
		if not con: continue
		res.append(i.name)
		
	return res

static func get_property_dict(obj: Object) -> Dictionary:
	var res := {}
	
	for i in get_property_keys(obj):
		var value = obj[i]
		
		if is_file_resource(value):
			value = encode_file_resource(value)

		res[i] = value

	return res

static func get_property_hash_dict(node: Node) -> Dictionary:
	var res := {}

	for i in get_property_keys(node):
		res[i] = hash(node[i])

	return res

static func is_file_resource(value) -> bool:
	return value and value is Resource and value.resource_path

static func is_encoded_file_resource(value) -> bool:
	return value is Dictionary and "_gdtRes" in value

static func encode_file_resource(resource: Resource) -> Dictionary:
	var res = {
		"_gdtRes": true,
		"path": resource.resource_path,
		"sub": {}
	}

	for key in get_property_keys(resource):
		var value = resource[key]

		if is_file_resource(value):
			res["sub"][key] = encode_file_resource(value)

	return res

static func decode_file_resource(dict: Dictionary) -> Resource:
	assert(is_encoded_file_resource(dict), "Provided dict isn't a resource dict")
	assert("path" in dict, "Resource dict doesn't contain path key")
	assert(GDTValidator.is_path_safe(dict["path"]), "Cannot load resource from unsafe path %s" % dict["path"])

	var res = load(dict["path"])

	if "sub" in dict:
		var sub = dict["sub"]

		if sub is Dictionary:
			for key in sub.keys():
				res[key] = decode_file_resource(sub[key])

	return res

func _ready() -> void:
	refrate.wait_time = REFRESH_RATE
	
	refrate.timeout.connect(_cycle)
	
	add_child(refrate)
	refrate.start()

func _cycle() -> void:
	var root := EditorInterface.get_edited_scene_root()
	
	if not main: return
	if not root: return
	
	var current_scene_path := root.scene_file_path
	if last_scene != current_scene_path:
		last_scene = current_scene_path
		scene_changed.emit()
	
	for node in observed_nodes:
		if not is_instance_valid(node):
			continue # Freed nodes are automatically erased from arrays but not instantly
		
		if not node.is_inside_tree():
			continue
		
		var cached: Dictionary = observed_nodes_cache[node]
		var current := get_property_hash_dict(node)
		
		var changed_keys: Array[String] = []
		
		for i in current.keys():
			if (not i in cached) or (not i in current) or (cached[i] != current[i]):
				#node_property_changed.emit(node, i)
				changed_keys.append(i)
				
		if changed_keys.size() != 0:
			if not supressed_nodes.has(node):
				node_properties_changed.emit(node, changed_keys)
			
			observed_nodes_cache[node] = current

func _node_added(node: Node) -> void:
	var current_scene := EditorInterface.get_edited_scene_root()
	var scene_path := current_scene.scene_file_path

	if scene_path in incoming_nodes:
		var incoming = incoming_nodes[scene_path]
		var node_path = node.get_path_to(current_scene)

		if node_path in incoming:
			incoming.erase(node_path)
			return

	if not node in observed_nodes:
		observe_recursive(node)
		node_added.emit(node)

func _node_exiting(node: Node) -> void:
	var scene = EditorInterface.get_edited_scene_root()
	if not scene: return

	if scene.is_ancestor_of(node):
		node_removed.emit(node)

func observe_current_scene() -> void:
	var scene = EditorInterface.get_edited_scene_root()
	if not scene: return
	
	main.change_detector.observe_recursive(scene)

	if not scene.tree_exiting.is_connected(delayed_observe_current_scene):
		scene.tree_exiting.connect(delayed_observe_current_scene)

func delayed_observe_current_scene() -> void:
	await get_tree().process_frame

	observe_current_scene()

func disconnect_signal_from_self(sig: Signal) -> void:
	for i in sig.get_connections():
		var fn: Callable = i.callable

		if fn.get_object() == self:
			sig.disconnect(fn)

func clear() -> void:
	for node in observed_nodes.keys():
		disconnect_signal_from_self(node.tree_exiting)
		disconnect_signal_from_self(node.child_entered_tree)
	
	observed_nodes.clear()
	observed_nodes_cache.clear()
	incoming_nodes.clear()

func pause() -> void:
	refrate.paused = true

func resume() -> void:
	refrate.paused = false

func merge(node: Node, property_dict: Dictionary) -> void:
	observe(node)
	
	for key in property_dict.keys():
		observed_nodes_cache[node][key] = hash(node[key])

func set_node_supression(node: Node, supressed: bool) -> void:
	if supressed:
		supressed_nodes.get_or_add(node, true)
	else:
		supressed_nodes.erase(node)

func get_observed_nodes() -> Array[Node]:
	var res: Array[Node]

	for i in observed_nodes.keys():
		res.append(i)

	return res

func suppress_add_signal(scene_path: String, node_path: NodePath) -> void:
	if not scene_path in incoming_nodes:
		incoming_nodes[scene_path] = []

	incoming_nodes[scene_path].append(node_path)

func observe(node: Node) -> void:
	if node in observed_nodes: return

	observed_nodes_cache[node] = get_property_hash_dict(node)
	observed_nodes[node] = {}

	node.tree_exiting.connect(_node_exiting.bind(node))
	node.child_entered_tree.connect(_node_added)

func observe_recursive(node: Node) -> void:
	observe(node)
	
	for i in GDTUtils.get_descendants(node):
		observe(i)
