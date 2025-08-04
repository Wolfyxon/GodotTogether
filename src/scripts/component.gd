@tool
extends Node
class_name GDTComponent

var main: GodotTogether

func _init(main: GodotTogether, name: String = "") -> void:
	self.main = main

	if name != "":
		self.name = "GodotTogether_" + name

	main.tree_exited.connect(queue_free)
