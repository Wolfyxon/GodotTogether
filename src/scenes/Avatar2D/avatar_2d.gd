@tool
extends Control
class_name GDTAvatar2D

@onready var txt = $txt

var id := -1
var user_ref: WeakRef

func _process(_delta: float) -> void:
	var user = get_user()
	if not user: return
	
	var scene = EditorInterface.get_edited_scene_root()
	if not scene: return
	if scene.is_queued_for_deletion(): return
	
	visible = user.current_scene == scene.scene_file_path

func set_user(user: GDTUser) -> void:
	user_ref = weakref(user)
	id = user.id
	modulate = user.color
	
	txt.get_node("name").text = user.name
	txt.get_node("class").text = user.get_type_as_string()

func get_user() -> GDTUser:
	if not user_ref:
		return
	
	return user_ref.get_ref() as GDTUser
