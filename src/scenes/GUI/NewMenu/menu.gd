@tool
extends PopupPanel
class_name GodotTogetherMenu

var main: GodotTogether

func _ready() -> void:
	if not visuals_available(): return
	
	$about/scroll/vbox/version.text = "Version: " + GodotTogether.VERSION

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		visible = true

func visuals_available() -> bool:
	return main or not Engine.is_editor_hint() 
