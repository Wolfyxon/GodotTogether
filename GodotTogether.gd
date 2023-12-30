@tool
extends BetterEditorPlugin_GodotTogether
class_name GodotTogether

const version = "1.0.0"
const compatibility_version = 1

var user_3d_scene = load("res://addons/GodotTogether/assets/scenes/User3D/User3D.tscn")
var user_2d_scene = load("res://addons/GodotTogether/assets/scenes/User2D/User2D.tscn")

var client = GodotTogetherClient.new()
var server = GodotTogetherServer.new()

func _enter_tree():
	create_user_3d()
	pass


func _exit_tree():
	pass

func create_user_3d(name:="Unknown") -> User3D:
	var usr = user_3d_scene.instantiate()
	usr.main = self
	add_child(usr)
	
	usr.set_username(name)
	return usr

func create_user_2d(name:="Unknown") -> User2D:
	var usr = user_2d_scene.instantiate()
	tree_exiting.connect(usr.queue_free)
	EditorInterface.get_editor_viewport_2d().add_child(usr)
	
	usr.set_username(name)
	return usr
