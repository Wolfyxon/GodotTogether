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
