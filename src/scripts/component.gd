@tool
extends Node
class_name GDTComponent

var main: GodotTogether
var component_ready = false

func _init(main: GodotTogether = null, name: String = "") -> void:
	self.main = main
	
	if name != "":
		self.name = "GodotTogether_" + name
	else:
		self.name = get_class()
	
	if main:
		main.tree_exiting.connect(queue_free)

func report_ready() -> void:
	component_ready = true
