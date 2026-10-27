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
	
	if current:
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
	
	if not editor_base:
		return
	
	var control = editor_base.get_base_editor()
	
	if control is CodeEdit:
		return control
	
	return

func get_current_line() -> int:
	var editor = get_code_editor()
	
	if not editor:
		return 0
	
	return editor.get_caret_line()
	
func update_text_edit(edit: TextEdit, text: String) -> void:
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
	
	# TODO: Recalculate caret positions to text differences
	
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
