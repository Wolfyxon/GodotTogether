@tool
extends Label
class_name GDTSceneWarning

var main: GodotTogether
var container: int

func _init(main: GodotTogether) -> void:
	self.main = main

	main.tree_exiting.connect(remove)

func _ready() -> void:
	text = "Unsaved scenes are not synced!"
	modulate = Color(1.0, 0.767, 0.0)

func _process(delta: float) -> void:
	var scene = EditorInterface.get_edited_scene_root()

	visible = not scene or scene.scene_file_path.is_empty()

func add(container: int):
	self.container = container
	main.add_control_to_container(container, self)

func remove():
	main.remove_control_from_container(container, self)
	queue_free()
