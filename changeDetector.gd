@tool
extends Node
class_name GodotTogetherChangeDetector

signal node_properties_changed(changed_keys: String)
signal node_property_changed(key: String)
signal node_property_differs(key: String, old_value, new_value)

var main:GodotTogether
var observed_nodes:Array[Node]

static func get_property_keys(node:Node) -> Array[String]:
	var res = []
	
	for i in node.get_property_list():
		res.append(i.name)
		
	return res

static func get_property_dict(node:Node) -> Dictionary:
	var res = {}
	
	for i in get_property_keys(node):
		res[i] = node[i]
	
	return res


func observe(node:Node):
	if node in observed_nodes: return
	observed_nodes.append(node)
	
	var cache = get_property_dict(node)
	
	node.property_list_changed.connect(func():
		var changed_keys = []
		var current = get_property_dict(node)
		
		for i in current.keys():
			if cache[i] != current[i]:
				node_property_changed.emit(i)
				node_property_differs.emit(i, cache[i], current[i])
				changed_keys.append(i)
		
		node_properties_changed.emit(changed_keys)
		cache = current
	)
