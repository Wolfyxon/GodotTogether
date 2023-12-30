@tool
extends BetterEditorPlugin_GodotTogether
class_name GodotTogether

var user_3d_scene = load("res://addons/GodotTogether/assets/scenes/User3D/User3D.tscn")
var user_2d_scene = load("res://addons/GodotTogether/assets/scenes/User2D/User2D.tscn")

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

