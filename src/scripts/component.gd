@tool
extends Node
class_name GDTComponent

var main: GodotTogether
var component_ready = false

func _init(_main: GodotTogether = null, _name: String = "") -> void:
	main = _main
	
	if _name != "":
		name = "GodotTogether_" + _name
	else:
		name = get_class()
	
	if main:
		main.tree_exiting.connect(queue_free)

func report_ready() -> void:
	component_ready = true
