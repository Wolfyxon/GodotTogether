@tool
extends GDTComponent
class_name GDTScriptSync

enum LineDiffOperation {
	SET,
	REMOVE,
	TERMINATE
}

var user_caret_scene = load("res://addons/GodotTogether/src/scenes/UserCaret/user_caret.tscn")

var main_editor = EditorInterface.get_script_editor()

var user_carets = []
var set_up_editor_ids = []

var supressed_scripts = {
	# [path]: bool
}

var last_sources = {
	# [script path]: [code]
}

func _ready() -> void:
	main.get_gui().external_script_change_dialog.got_external_changes.connect(_gd_script_external_changes)
	main_editor.editor_script_changed.connect(_script_changed)
	
	report_ready()
	
	await get_tree().process_frame
	setup_current_editor()

func _exit_tree() -> void:
	clear_user_carets()

func _script_changed(_script: Script) -> void:
	setup_current_editor()

func _script_code_changed(editor: ScriptEditorBase, code_edit: CodeEdit) -> void:
	if main_editor.get_current_editor() != editor:
		return
	
	var script = main_editor.get_current_script()
	if not script: return
	if not script.resource_path: return
	
	if script.resource_path in supressed_scripts:
		return
	
	if not GDTValidator.is_path_safe(script.resource_path):
		return
	
	var diff = []
	
	if script.resource_path in last_sources:
		diff = get_line_diff(last_sources[script.resource_path], code_edit.text)
	else:
		diff = get_line_diff("", code_edit.text)
	
	set_last_source_code(script.resource_path, code_edit.text)
	
	if main.server.is_active():
		server_broadcast_script_line_diff(script.resource_path, diff)
	elif main.client.is_active():
		_c2s_script_line_diff_upload_request.rpc_id(1, script.resource_path, diff)
	
	#if main.server.is_active():
	#	server_broadcast_script(script.resource_path, code_edit.text)
	#elif main.client.is_active():
	#	_c2s_script_update_request.rpc_id(1, script.resource_path, code_edit.text)


func _gd_script_external_changes(_paths: Array) -> void:
	if not main: return
	
	var settings = main.get_settings()
	if not settings: return
	
	if not main.is_session_active() and not settings.get_setting("dev/allow_file_reload_outside_sessions"):
		return
	
	if not settings.get_setting("files/auto_reload_files"):
		return
	
	main.get_gui().external_script_change_dialog.reload()

func setup_current_editor() -> void:
	if not main: return
	
	var script = EditorInterface.get_script_editor().get_current_script()
	if not script: return
	if not script.resource_path: return
	
	var editor = main_editor.get_current_editor()
	
	var code_edit = main.gui.script_editor_mgr.get_code_editor(editor)
	if not code_edit: return
	if code_edit.is_queued_for_deletion(): return
	
	if code_edit.get_instance_id() in set_up_editor_ids:
		return
	
	set_last_source_code(script.resource_path, code_edit.text)
	code_edit.text_changed.connect(_script_code_changed.bind(editor, code_edit))
	set_up_editor_ids.append(code_edit.get_instance_id())

func set_last_source_code(path: String, code: String) -> void:
	last_sources[path] = code

func set_script_supressed(path: String, state: bool) -> void:
	if state:
		supressed_scripts[path] = true
	else:
		supressed_scripts.erase(path)


func create_user_caret(user: GDTUser) -> void:
	if not user_caret_scene:
		GDTUtils.printerr_stack("Cannot create user caret. Source scene is null")
		return
	
	var caret: GDTUserCaret = user_caret_scene.instantiate()
	
	caret.main = main
	caret.set_user(user)
	main_editor.add_child(caret)
	user_carets.append(caret)

func get_user_caret(id: int) -> GDTUserCaret:
	for i in user_carets:
		if not i: continue
		
		var user = i.get_user()
		if not user: continue
		
		if user.id == id:
			return i
			
	return

func remove_user_caret(id: int) -> void:
	var caret = get_user_caret(id)
	if not caret: return
	
	caret.queue_free()
	user_carets.erase(caret)

func clear_user_carets() -> void:
	for i in user_carets:
		if i:
			i.queue_free()
			
	user_carets.clear()

func update_script(path: String, code: String) -> void:
	# TODO: Update when script isn't open
	
	var current_script = main_editor.get_current_script()
	if not current_script: return
	if current_script.is_queued_for_deletion(): return
	if current_script.resource_path != path: return
	
	var code_edit = main.gui.script_editor_mgr.get_code_editor()
	if not code_edit: return
	
	set_script_supressed(path, true)
	
	code = main.script_security.sanitize_gdscript(code)
	
	main.gui.script_editor_mgr.update_text_edit(code_edit, code)
	
	set_script_supressed(path, false)

@rpc("authority", "reliable", "call_remote", GDTDual.NetChannel.SCRIPTS)
func apply_script_line_diff(path: String, diff: Array) -> void:
	if not GDTValidator.is_path_safe(path): return
	
	var current_script = main_editor.get_current_script()
	if not current_script: return
	if current_script.is_queued_for_deletion(): return
	if current_script.resource_path != path: return
	
	var edit = main.gui.script_editor_mgr.get_code_editor()
	if not edit: return
	if edit.is_queued_for_deletion(): return
	
	set_script_supressed(path, true)
	
	var applied = apply_line_diff(edit.text, diff)
	var code = main.script_security.sanitize_gdscript(applied)
	
	set_last_source_code(path, code)
	main.gui.script_editor_mgr.update_text_edit(edit, code)
	
	set_script_supressed(path, false)

@rpc("authority", "reliable", "call_remote", GDTDual.NetChannel.SCRIPTS)
func _s2c_receive_script(path: String, code: String) -> void:
	if not main.client.validate_s2c(): return
	if not GDTValidator.is_path_safe(path): return
	
	update_script(path, code)

@rpc("any_peer", "reliable", "call_remote", GDTDual.NetChannel.SCRIPTS)
func _c2s_script_line_diff_upload_request(path: String, diff: Array) -> void:
	if not main.server.validate_c2s(): return
	
	var id = multiplayer.get_remote_sender_id()
	
	var user = main.dual.get_user_by_id(id)
	if not user: return
	
	if not user.has_permission(GodotTogether.Permission.EDIT_SCRIPTS):
		return
		
	apply_script_line_diff(path, diff)
	server_broadcast_script_line_diff(path, diff, id)

@rpc("any_peer", "reliable", "call_remote", GDTDual.NetChannel.SCRIPTS)
func _c2s_script_update_request(path: String, code: String) -> void:
	var id = multiplayer.get_remote_sender_id()
	
	if not main.server.validate_c2s(): return
	if not GDTValidator.is_path_safe(path): return
	
	var user = main.dual.get_user_by_id(id)
	if not user: return
	
	if not user.has_permission(GodotTogether.Permission.EDIT_SCRIPTS):
		return
	
	update_script(path, code)
	server_broadcast_script(path, code, id)

func server_broadcast_script(path: String, code: String, sender := 1) -> void:
	main.server.auth_rpc(_s2c_receive_script, [path, code], [sender])

func server_broadcast_script_line_diff(path: String, diff: Array, sender := 1) -> void:
	main.server.auth_rpc(apply_script_line_diff, [path, diff], [sender])

static func get_line_diff(old_text: String, new_text: String) -> Array:
	var old_lines = old_text.remove_chars("\r").split("\n")
	var new_lines = new_text.remove_chars("\r").split("\n")
	
	var res: Array = []
	
	for i in new_lines.size():
		if i < old_lines.size():
			if old_lines[i] == new_lines[i]:
				continue
				
		res.append({
			"line": i,
			"mode": LineDiffOperation.SET,
			"text": new_lines[i]
		})
		
	
	res.append({
		"line": new_lines.size(),
		"mode": LineDiffOperation.TERMINATE
	})
	
	return res

static func apply_line_diff(text: String, diff: Array) -> String:
	var lines = text.split("\n")
	
	for line_diff in diff:
		if not "mode" in line_diff:
			continue
		if not "line" in line_diff:
			continue
			
		var mode: LineDiffOperation = line_diff["mode"]
		var line_i: int = line_diff["line"]
		
		if mode == LineDiffOperation.TERMINATE:
			lines.resize(line_i)
			break
		elif mode == LineDiffOperation.SET:
			var line_text = line_diff["text"]
			
			if line_i < lines.size():
				lines[line_i] = line_text
			else:
				lines.append(line_text)
	
	return GDTUtils.join(lines, "\n")
