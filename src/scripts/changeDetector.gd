@tool
extends Node
class_name GodotTogetherChangeDetector

signal node_properties_changed(node: Node, changed_keys: String)
signal node_property_changed(node: Node, key: String)
signal node_property_differs(node: Node, key: String, old_value, new_value)

const IGNORED_PROPERTY_USAGE_FLAGS = [
	PROPERTY_USAGE_GROUP, 
	PROPERTY_USAGE_CATEGORY, 
	PROPERTY_USAGE_SUBGROUP
]

var main: GodotTogether
var observed_nodes: Array[Node]

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


func observe(node: Node):
	if node in observed_nodes: return
	observed_nodes.append(node)
	
	var cache = get_property_dict(node)
	
	var on_change = func():
		var changed_keys = []
		var current = get_property_dict(node)
		
		for i in current.keys():
			if cache[i] != current[i]:
				node_property_changed.emit(node, i)
				node_property_differs.emit(node, i, cache[i], current[i])
				changed_keys.append(i)
		
		node_properties_changed.emit(node, changed_keys)
		cache = current
	
	node.property_list_changed.connect(on_change)
	node.tree_exiting.connect(func():
		node.property_list_changed.disconnect(on_change)
	)

func observe_recursive(node: Node):
	observe(node)
	
	for i in main.get_descendants(node):
		observe(i)
