@tool
extends Node
class_name GodotTogetherComponent

var main: GodotTogether

func _init(main: GodotTogether, name: String = "") -> void:
	self.main = main

	if name != "":
		self.name = name