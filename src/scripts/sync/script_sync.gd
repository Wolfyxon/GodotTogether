@tool
extends GDTComponent
class_name GDTScriptSync

var main_editor = EditorInterface.get_script_editor()

var set_up_editor_ids = []

func _ready() -> void:
	report_ready() # Currently this script doesn't do anything so who cares if an error occurs
	
	main_editor.script_changed.connect(setup_current_editor)
	
	await get_tree().process_frame
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

func _script_code_editor_changed(_editor: ScriptEditorBase, _code_edit: CodeEdit) -> void:
	pass
