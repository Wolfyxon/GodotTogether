@tool
extends Control
class_name User2D

var id := -1 

@onready var txt = $txt

func set_username(name:String):
	txt.get_node("name").text = name

func set_position_percent(vector:Vector2):
	global_position = Vector2(EditorInterface.get_editor_viewport_2d().size) * vector
