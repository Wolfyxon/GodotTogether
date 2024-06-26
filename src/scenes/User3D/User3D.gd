@tool
extends Node3D
class_name User3D

var id := -1

@onready var ui = $ui.duplicate()
@onready var text_ui = ui.get_node("txt")

var main:GodotTogether

func _ready():
	if not main: return
	$ui.visible = false
	ui.visible = true
	EditorInterface.get_editor_viewport_3d().add_child(ui)
	
func _exit_tree():
	if not ui: return
	ui.queue_free()
	
func _process(delta):
	if not main: return
	var cam =  main.get_editor_3d_camera()
	var dist = cam.position.distance_to(position)
	ui.position = cam.unproject_position(position) - ui.size/2 - (Vector2(0,200)/dist)

func set_username(name:String):
	while not ui: await get_tree().physics_frame
	text_ui.get_node("name").text = name