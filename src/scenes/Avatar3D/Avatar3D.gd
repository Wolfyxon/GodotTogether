@tool
extends Node3D
class_name GodotTogetherAvatar3D

const MATERIAL: StandardMaterial3D = preload("res://addons/GodotTogether/src/scenes/Avatar3D/material.tres")

@onready var model = $model
@onready var ui = $ui.duplicate()
@onready var text_ui = ui.get_node("txt")

var id := -1
var main: GodotTogether

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

	var cam = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	var dist = cam.position.distance_to(position)
	
	ui.visible = cam.is_position_in_frustum(position)
	ui.position = cam.unproject_position(position) - ui.size / 2 - (Vector2(0, 200) / dist)

func set_user(user: GodotTogetherUser):
	while not ui: await get_tree().physics_frame

	text_ui.get_node("name").text = user.name
	text_ui.get_node("class").text = user.get_type_as_string()

	id = user.id

	var material = MATERIAL.duplicate()
	material.albedo_color = user.color

	for i in model.get_children():
		if i is MeshInstance3D:
			i.mesh.surface_set_material(material)
