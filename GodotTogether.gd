@tool
extends BetterEditorPlugin_GodotTogether
class_name GodotTogether

const user_3d_scene = preload("res://addons/GodotTogether/assets/scenes/User3D/User3D.tscn")

func _enter_tree():
	create_user_3d()
	pass


func _exit_tree():
	pass

func create_user_3d() -> User3D:
	var usr = user_3d_scene.instantiate()
	usr.main = self
	add_child(usr)
	return usr
