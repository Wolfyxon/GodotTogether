@tool
extends Label
class_name GDTSceneWarning

var main: GodotTogether
var container: int

func _init(_main: GodotTogether) -> void:
	main = _main
	main.tree_exiting.connect(remove)

func _ready() -> void:
	text = "Unsaved scenes are not synced!"
	modulate = Color(1.0, 0.767, 0.0)

func _process(_delta: float) -> void:
	var scene = EditorInterface.get_edited_scene_root()
	visible = not scene or scene.scene_file_path.is_empty()

func add(new_container: int):
	container = new_container
	main.add_control_to_container(new_container, self)

func remove():
	main.remove_control_from_container(container, self)
	queue_free()
