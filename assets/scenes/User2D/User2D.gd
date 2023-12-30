@tool
extends Control
class_name User2D

@onready var txt = $txt

func set_username(name:String):
	txt.get_node("name").text = name
