@tool
extends Node
class_name GDTComponent

var main: GodotTogether

func _init(main: GodotTogether = null, name: String = "") -> void:
	self.main = main

	if name != "":
		self.name = "GodotTogether_" + name
	
	if main:
		main.tree_exiting.connect(queue_free)
