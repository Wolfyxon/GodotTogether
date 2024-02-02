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

static func properties_to_dict(node:Node) -> Dictionary:
	var res = {}
	
	for i in get_property_keys(node):
		res[i] = node[i]
	
	return res
