extends PopupPanel
class_name GodotTogetherMenu

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		visible = true
