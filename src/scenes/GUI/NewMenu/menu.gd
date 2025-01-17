@tool
extends PopupPanel
class_name GodotTogetherMenu

var main: GodotTogether

func _ready() -> void:
	if not visuals_available(): return
	
	main_menu()
	$about/scroll/vbox/version.text = "Version: " + GodotTogether.VERSION

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		visible = true

func main_menu() -> void:
	$main/sessionInit/start.visible = false
	$main/sessionInit/pre.visible = true

func visuals_available() -> bool:
	return main or not Engine.is_editor_hint() 
