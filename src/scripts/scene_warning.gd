@tool
extends Label
class_name GDTSceneWarning

var main: GodotTogether
var container: int

func _init(_main: GodotTogether) -> void:
	main = _main
	main.tree_exiting.connect(remove)

func _ready() -> void:
	modulate = Color(1.0, 0.767, 0.0)

func _process(_delta: float) -> void:
	var scene = EditorInterface.get_edited_scene_root()
	
	if not scene:
		text = "Scenes without root node are not synced!"
		visible = true
	elif scene.scene_file_path.is_empty():
		text = "Unsaved scenes are not synced!"
		visible = true
	elif not GDTValidator.is_path_safe(scene.scene_file_path):
		text = "This scene is not synced for security."
		visible = true
	else:
		visible = false


func add(new_container: int):
	container = new_container
	main.add_control_to_container(new_container, self)

func remove():
	main.remove_control_from_container(container, self)
	queue_free()
