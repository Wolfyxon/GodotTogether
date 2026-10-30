@tool
extends GDTComponent
class_name GDTScriptSync

var user_caret_scene = load("res://addons/GodotTogether/src/scenes/UserCaret/user_caret.tscn")

var main_editor = EditorInterface.get_script_editor()

var user_carets = []
var set_up_editor_ids = []

var supressed_scripts = {
	# path: bool
}

func _ready() -> void:
	report_ready() # Currently this script doesn't do anything so who cares if an error occurs
	
	main.get_gui().external_script_change_dialog.got_external_changes.connect(_gd_script_external_changes)
	main_editor.editor_script_changed.connect(_script_changed)
	
	await get_tree().process_frame
	setup_current_editor()

func _exit_tree() -> void:
	clear_user_carets()

func _script_changed(_script: Script) -> void:
	setup_current_editor()

func _gd_script_external_changes(_paths: Array) -> void:
	if not main: return
	
	var settings = main.get_settings()
	if not settings: return
	
	if not main.is_session_active() and not settings.get_setting("dev/allow_file_reload_outside_sessions"):
		return
	
	if not settings.get_setting("files/auto_reload_files"):
		return
	
	main.get_gui().external_script_change_dialog.reload()

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

func setup_current_editor() -> void:
	if not main: return
	
	var editor = main_editor.get_current_editor()
	
	var code_edit = main.gui.script_editor_mgr.get_code_editor(editor)
	if not code_edit: return
	if code_edit.is_queued_for_deletion(): return
	
	if code_edit.get_instance_id() in set_up_editor_ids:
		return
	
	code_edit.text_changed.connect(_script_code_editor_changed.bind(editor, code_edit))
	set_up_editor_ids.append(code_edit.get_instance_id())

func _script_code_editor_changed(editor: ScriptEditorBase, code_edit: CodeEdit) -> void:
	if main_editor.get_current_editor() != editor:
		return
	
	var script = main_editor.get_current_script()
	if not script: return
	if not script.resource_path: return
	
	if script.resource_path in supressed_scripts:
		return
	
	if not GDTValidator.is_path_safe(script.resource_path):
		return
	
	if main.server.is_active():
		server_broadcast_script(script.resource_path, code_edit.text)
	elif main.client.is_active():
		_c2s_script_update_request.rpc_id(1, script.resource_path, code_edit.text)

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

func set_script_supressed(path: String, state: bool) -> void:
	if state:
		supressed_scripts[path] = true
	else:
		supressed_scripts.erase(path)

@rpc("authority", "reliable", "call_remote", GDTDual.NetChannel.SCRIPTS)
func _s2c_receive_script(path: String, code: String) -> void:
	if not main.client.validate_s2c(): return
	if not GDTValidator.is_path_safe(path): return
	
	update_script(path, code)

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
