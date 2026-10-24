@tool
extends GDTComponent
class_name GDTScriptEditorManager

var main_editor: ScriptEditor = null

func _ready() -> void:
	main_editor = EditorInterface.get_script_editor()
	
	main_editor.editor_script_changed.connect(_script_changed)
	
	report_ready()

func _script_changed(_script: Script) -> void:
	update()

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
