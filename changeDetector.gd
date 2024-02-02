@tool
extends Node
class_name GodotTogetherChangeDetector

var main:GodotTogether

signal node_properties_changed

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
	var cache = get_property_dict(node)
	
	node.property_list_changed.connect(func():
		var changed_keys = []
		var current = get_property_dict(node)
		
		for i in current.keys():
			if cache[i] != current[i]:
				changed_keys.append(i)
		
		node_properties_changed.emit(changed_keys)
	)
