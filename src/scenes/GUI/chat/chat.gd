@tool
extends VBoxContainer
class_name GDTChat

var main: GodotTogether

func _ready() -> void:
	if not main: return
	
	var scroll_style = EditorInterface.get_editor_theme().get_stylebox("panel", "Panel")
	
	$scroll.add_theme_stylebox_override("panel", scroll_style)
