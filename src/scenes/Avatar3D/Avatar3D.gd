@tool
extends Node3D
class_name GDTAvatar3D

const MATERIAL: StandardMaterial3D = preload("material.tres")

@onready var model = $model
@onready var ui = $ui.duplicate()
@onready var text_ui = ui.get_node("txt")

var id := -1
var main: GodotTogether
var received_update := false

func _ready() -> void:
	if not main: return
	$ui.visible = false
	ui.visible = true
	EditorInterface.get_editor_viewport_3d().add_child(ui)
	
func _exit_tree() -> void:
	if not ui: return
	ui.queue_free()


func receive_transform(pos: Vector3, rot: Vector3) -> void:
	position = pos
	rotation = rot
	received_update = true

func _process(delta) -> void:
	if not main: return

	# Nothing to show yet (avatar still sitting at its default Vector3.ZERO),
	# and unproject_position() below is not safe to call for a point that
	# happens to line up with the camera.
	if not received_update:
		ui.visible = false
		return

	var cam = EditorInterface.get_editor_viewport_3d().get_camera_3d()
	if not cam:
		ui.visible = false
		return

	var dist = cam.position.distance_to(position)

	# Fix the "Condition p.d == 0 is true" error. 
	if dist < 0.1 or cam.is_position_behind(position):
		ui.visible = false
		return

	dist += 0.05 # Extra distance to prevent division by 0

	ui.visible = cam.is_position_in_frustum(position)
	ui.position = cam.unproject_position(position) - ui.size / 2 - (Vector2(0, 200) / dist)

func set_user(user: GDTUser) -> void:
	while not ui: await get_tree().physics_frame

	text_ui.get_node("name").text = user.name
	text_ui.get_node("class").text = user.get_type_as_string()

	id = user.id

	var material = MATERIAL.duplicate()

	material.albedo_color = user.color
	material.albedo_color.a = MATERIAL.albedo_color.a

	for i in model.get_children():
		if i is MeshInstance3D:
			i.mesh.material = material
