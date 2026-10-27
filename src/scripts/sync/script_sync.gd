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
	
	code_edit.text_changed.connect(_script_code_editor_changed.bind(code_edit))
	set_up_editor_ids.append(code_edit.get_instance_id())

func _script_code_editor_changed(_editor: ScriptEditorBase, _code_edit: CodeEdit) -> void:
	pass

func update_code_edit(edit: CodeEdit, text: String) -> void:
	var carets = [
		# [line, column]
	]
	
	var selections = [
		# [line, column]
	]
	
	var scroll_v = edit.scroll_vertical
	var scroll_h = edit.scroll_horizontal
	
	for caret_i in edit.get_caret_count():
		var line = edit.get_caret_line(caret_i)
		var column = edit.get_caret_column(caret_i)
		
		carets.append([line, column])
		
		var sel_line_end = edit.get_selection_to_line(caret_i)
		var sel_column_end = edit.get_selection_to_column(caret_i)
		
		if sel_line_end == line and sel_column_end == column:
			continue 
			
		selections.append([sel_line_end, sel_column_end])
	
	edit.text = text
	edit.scroll_horizontal = scroll_h
	edit.scroll_vertical = scroll_v
	
	for caret_i in carets.size():
		var line = carets[caret_i][0]
		var col = carets[caret_i][1]
		
		edit.set_caret_line(line, true, true, 0, caret_i)
		edit.set_caret_column(col, true, caret_i)
		
	for caret_i in selections.size():
		var line = carets[caret_i][0]
		var col = carets[caret_i][1]
		var line_end = carets[caret_i][0]
		var col_end = carets[caret_i][1]
		
		edit.select(line, col, line_end, col_end, caret_i)
