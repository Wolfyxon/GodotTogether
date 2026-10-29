@tool
extends GDTComponent
class_name GDTScriptEditorManager

signal script_position_changed

var main_editor: ScriptEditor = null

func _ready() -> void:
	main_editor = EditorInterface.get_script_editor()
	
	main_editor.editor_script_changed.connect(_script_changed)
	
	_script_changed(main_editor.get_current_script())
	report_ready()

func _script_changed(_script: Script) -> void:
	if not _script: return
	if not main: return
	
	var current = main_editor.get_current_editor()
	
	if current and not current.is_queued_for_deletion():
		setup_editor(current)
	
	update()

func setup_editor(editor: ScriptEditorBase) -> void:
	var control = editor.get_base_editor()
	
	if not control is CodeEdit: 
		return
	
	GDTUtils.try_connect(
		control.caret_changed, 
		_editor_caret_position_changed.bind(control)
	)

func _editor_caret_position_changed(_control: CodeEdit) -> void:
	if not main: return
	script_position_changed.emit()

func update() -> void:
	pass

func get_code_editor(editor_base: ScriptEditorBase = null) -> CodeEdit:
	if not editor_base:
		editor_base = main_editor.get_current_editor()
	
	if not editor_base: return
	if editor_base.is_queued_for_deletion(): return
	
	var control = editor_base.get_base_editor()
	if not control: return
	if control.is_queued_for_deletion(): return
	
	if control is CodeEdit:
		return control
	
	return

func get_current_line() -> int:
	var editor = get_code_editor()
	
	if not editor:
		return 0
	
	return editor.get_caret_line()

func get_current_column() -> int:
	var editor = get_code_editor()
	
	if not editor:
		return 0
	
	return editor.get_caret_column()

func save_text_edit_state(edit: TextEdit) -> Dictionary:
	if edit.is_queued_for_deletion():
		GDTUtils.printerr_stack("Cannot save. Given TextEdit is queued for deletion")
		return {}
	
	var last_text = edit.text
	var caret_idxes = []
	var selection_end_idxs = []
	
	for caret_i in edit.get_caret_count():
		var line = edit.get_caret_line(caret_i)
		var column = edit.get_caret_column(caret_i)
		var idx = GDTUtils.line_column_to_index(last_text, line, column)
		
		caret_idxes.append(idx)
		
		var sel_line_end = edit.get_selection_to_line(caret_i)
		var sel_column_end = edit.get_selection_to_column(caret_i)
		
		if sel_line_end == line and sel_column_end == column:
			continue 
		
		var end_idx = GDTUtils.line_column_to_index(last_text, sel_line_end, sel_column_end)
		
		selection_end_idxs.append(end_idx)
	
	return {
		"last_text": edit.text,
		"caret_idxes": caret_idxes,
		"selection_end_idxs": selection_end_idxs,
		"scroll_v": edit.scroll_vertical,
		"scroll_h": edit.scroll_horizontal
	}

func restore_text_edit_state(edit: TextEdit, data: Dictionary) -> void:
	if edit.is_queued_for_deletion():
		return
	
	if not data:
		GDTUtils.printerr_stack("Unable to restore state. Got empty dictionary")
		return
	
	var caret_idxes = data["caret_idxes"]
	var selection_end_idxs = data["selection_end_idxs"]
	var last_text = data["last_text"]
	
	# TODO: Recalculate caret positions to text differences
	
	edit.scroll_horizontal = data["scroll_h"]
	edit.scroll_vertical = data["scroll_v"]
	
	for caret_i in caret_idxes.size():
		var lc = GDTUtils.index_to_line_column(last_text, caret_idxes[caret_i])
		
		edit.set_caret_line(lc[0], true, true, 0, caret_i)
		edit.set_caret_column(lc[1], true, caret_i)
	
	for caret_i in selection_end_idxs.size():
		var lc_start = GDTUtils.index_to_line_column(last_text, caret_idxes[caret_i])
		var lc_end = GDTUtils.index_to_line_column(last_text, selection_end_idxs[caret_i])
		
		var line = lc_start[0] 
		var col = lc_start[1]
		var line_end = lc_end[0]
		var col_end = lc_end[1]
		
		edit.select(line, col, line_end, col_end, caret_i)
		

func update_text_edit(edit: TextEdit, text: String) -> void:
	if edit.text == text: 
		return
	
	var state = save_text_edit_state(edit)
	
	edit.text = text
	
	restore_text_edit_state(edit, state)
