@tool
extends Control
class_name GDTAvatar2D

var id := -1 

@onready var txt = $txt

func set_user(user: GDTUser):
	id = user.id
	modulate = user.color
	
	txt.get_node("name").text = user.name
	txt.get_node("class").text = user.get_type_as_string()

func set_position_percent(vector: Vector2):
	global_position = Vector2(EditorInterface.get_editor_viewport_2d().size) * Vector2(vector)
