@tool
extends PopupPanel
class_name GodotTogetherMainMenu

var main:GodotTogether

func _ready():
	pass

func _process(delta):
	if not Engine.is_editor_hint(): popup()

func toggle():
	if not visible: popup()
	else: visible = false


func _on_btn_host_pressed():
	pass # Replace with function body.


func _on_btn_join_pressed():
	pass # Replace with function body.
