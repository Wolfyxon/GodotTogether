@tool
extends Node2D
class_name GDTUserCaret

var main: GodotTogether = null
var user_ref: WeakRef = null

func _process(_delta: float) -> void:
	if not main: return
	
	var user = get_user()
	if not user: return
	
	visible = false
	
	var current_script = EditorInterface.get_script_editor().get_current_script()
	if not current_script: return
	if current_script.is_queued_for_deletion(): return
	if not current_script.resource_path: return
	
	if current_script.resource_path != user.current_script:
		return
	
	var edit = main.gui.script_editor_mgr.get_code_editor()
	if not edit: return
	
	var lines = edit.text.remove_chars("\r").split("\n")
	var col = user.current_script_column
	
	if lines.size() <= user.current_script_line:
		return
		
	var line_text = lines[user.current_script_line]
	
	if line_text.length() <= user.current_script_column:
		col = 0
	
	var local_pos = edit.get_pos_at_line_column(user.current_script_line, col)
	if local_pos.x == -1: return
	
	global_position = edit.global_position + Vector2(local_pos)
	visible = true

func set_user(user: GDTUser) -> void:
	$color.color = user.color
	$usernameContainer/label/bg.color = user.color
	$usernameContainer/label.text = user.name
	
	user_ref = weakref(user)

func get_user() -> GDTUser:
	if not user_ref:
		return
	
	return user_ref.get_ref()
	
