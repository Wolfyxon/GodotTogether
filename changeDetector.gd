@tool
extends Node
class_name GodotTogetherChangeDetector

var main:GodotTogether

signal node_property_changed

static func get_property_keys(node:Node) -> Array[String]:
	var res = []
	
	for i in node.get_property_list():
		res.append(i.name)
		
	return res
