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
