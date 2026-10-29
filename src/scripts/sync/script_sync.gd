@tool
extends GDTComponent
class_name GDTScriptSync

var main_editor = EditorInterface.get_script_editor()

var set_up_editor_ids = []

var supressed_scripts = {
	# path: bool
}

func _ready() -> void:
	report_ready() # Currently this script doesn't do anything so who cares if an error occurs
	
	main_editor.editor_script_changed.connect(_script_changed)
	
	await get_tree().process_frame
	setup_current_editor()

func _script_changed(_script: Script) -> void:
	setup_current_editor()

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
	
	code = main.script_security.sanitize_gdscript(code)
	
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
