@tool
extends Node
class_name GodotTogetherComponent

func _init(main: GodotTogether, name: String = "") -> void:
	self.main = main

	if name != "":
		self.name = name