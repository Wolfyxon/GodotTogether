@tool
extends GodotTogetherComponent
class_name GodotTogetherChangeDetector

signal scene_changed
signal node_properties_changed(node: Node, changed_keys: Array)
#signal node_property_changed(node: Node, key: String)
#signal node_property_differs(node: Node, key: String, old_value, new_value)
signal node_removed(node: Node)
signal node_added(node: Node)

const IGNORED_PROPERTY_USAGE_FLAGS := [
	PROPERTY_USAGE_GROUP, 
	PROPERTY_USAGE_CATEGORY, 
	PROPERTY_USAGE_SUBGROUP
]

var observed_nodes := {}
var observed_nodes_cache := {}
var incoming_nodes := {
	# scene path: Array[NodePath]
}
var refrate: Timer = Timer.new()

var last_scene := ""

static func get_property_keys(node: Node) -> Array[String]:
	var res: Array[String] = []
	
	for i in node.get_property_list():
		var con := true
		
		for usage in IGNORED_PROPERTY_USAGE_FLAGS:
			if i.usage & usage:
				con = false
				break
			
		if not con: continue
		res.append(i.name)
		
	return res

static func get_property_dict(node: Node) -> Dictionary:
	var res := {}
	
	for i in get_property_keys(node):
		res[i] = node[i]
	
	return res

func _ready() -> void:
	# ImmortalOctogen: there is no data races and other data sync problems
	# 'observed_nodes', 'observed_nodes_cache', 'incoming_nodes' is only used by other thread
	var t: Thread = Thread.new() # Creating thread once saves fps
	refrate.wait_time = 0.1
	refrate.timeout.connect(func():
		if t.start(cycle) == ERR_CANT_CREATE:
			print_debug(error_string(ERR_CANT_CREATE)) # for smth
			return
		while true:
			if !t.is_alive():
				t.wait_to_finish()
				break
		)
	add_child(refrate)
	refrate.start()

# The thread-only function
func cycle() -> void:
	if not main: return
	
	
	var root := EditorInterface.call_deferred("get_edited_scene_root")
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
		
		var cached: Dictionary = observed_nodes_cache[node]
		var current := get_property_dict(node)
		
		var changed_keys: Array[Array] = []
		
		for i in current.keys():
			if cached[i] != current[i]:
				#node_property_changed.emit(node, i)
				#node_property_differs.emit(node, i, cached[i], current[i])
				changed_keys.append(i)
				
		if changed_keys.size() != 0:
			node_properties_changed.emit(node, changed_keys)
			observed_nodes_cache[node] = current

# Calculation is freed from main thread. Commented with String.
func _process(_delta) -> void:
	"if not main: return
	
	
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
		
		var cached: Dictionary = observed_nodes_cache[node]
		var current := get_property_dict(node)
		
		var changed_keys: Array[Array] = []
		
		for i in current.keys():
			if cached[i] != current[i]:
				#node_property_changed.emit(node, i)
				#node_property_differs.emit(node, i, cached[i], current[i])
				changed_keys.append(i)
				
		if changed_keys.size() != 0:
			node_properties_changed.emit(node, changed_keys)
			observed_nodes_cache[node] = current"

func _node_added(node: Node):
	var current_scene := EditorInterface.get_edited_scene_root()
	var scene_path := current_scene.scene_file_path

	if scene_path in incoming_nodes:
		var incoming = incoming_nodes[scene_path]
		var node_path = node.get_path_to(current_scene)

		if node_path in incoming:
			incoming.erase(node_path)
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
	node.child_entered_tree.connect(_node_added)
	
	# ImmortalOctogen: gigachad coding??!!!
	# property_list_changed doesn't fire in editor
	# so let's fire `em!
	# P.S. forget for while
	#var script: GDScript = node.get_script() as GDScript
	#if script == null:
	#	return
	#print(script.get_global_name())
	#print(script.get_script_method_list())
	
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
