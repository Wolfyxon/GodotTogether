@abstract
extends GDTNodeWrapper
class_name GDTExternalChangeDialogBase

signal got_external_changes(paths: Array)
signal changes_ignored
signal changes_resaved
signal changes_reloaded

var node: ConfirmationDialog
var tree: Tree

var last_reload_time := 0.0

func _wrapper_init() -> void:
	_acquire_node()
	
	if not node: 
		return
	
	_setup_signals()

@abstract
func _acquire_node() -> void

@abstract
func _check_dialog(dialog: ConfirmationDialog) -> bool

# Godot commit: 63b7e027254e6b77b3d1036c89973060fb5be088
# Source: editor/editor_node.cpp line: 9648
# and:    editor/script/script_editor_plugin.cpp line: 4308
# Structure: 
#	ConfirmationDialog:
#		VBoxContainer
#			Label ("The following files are newer on disk:")
#			Tree
#			Label ("What action should be taken?)
# Buttons:
#	<Cancel>: Do nothing.
#	<Confirm>: Reload
#	"resave"
func _check_and_use(dialog: ConfirmationDialog) -> bool:
	# Do not check strings. Will break with other languages than English.
	
	if dialog.get_child_count() != 1:
		return false
	
	var vbox = dialog.get_child(0)
	
	if not vbox is VBoxContainer: return false
	if vbox.get_child_count() != 3: return false
	
	var file_tree = vbox.get_child(1)
	if not file_tree is Tree: return false
	
	if not _check_dialog(dialog):
		return false
	
	node = dialog
	tree = file_tree
	
	return true

func _setup_signals() -> void:
	node.custom_action.connect(func(action: String):
		if action == "resave":
			_resaved()
	)
	node.canceled.connect(_cancelled)
	node.confirmed.connect(_reloaded)
	
	node.visibility_changed.connect(_window_visibility_changed)

func _window_visibility_changed():
	if node.visible:
		_got_changes(get_paths())

func _got_changes(paths: Array) -> void:
	got_external_changes.emit(paths)

func _cancelled():
	changes_ignored.emit()

func _resaved():
	changes_resaved.emit()
	pass

func _reloaded():
	EditorInterface.get_selection().clear()
	last_reload_time = Time.get_unix_time_from_system()
	
	changes_reloaded.emit()

func ignore_and_resave() -> void:
	node.custom_action.emit("resave")

func ignore_without_saving() -> void:
	node.hide()

func reload() -> void:
	push_warning("[GodotTogether] Reloading external changes. This can cause a crash!")
	
	for i in get_paths():
		push_warning("- ", i)
	
	last_reload_time = Time.get_unix_time_from_system()
	await node.get_tree().process_frame
	node.confirmed.emit()

func get_raw_paths() -> Array:
	var res = []
	var root = tree.get_root()
	
	if not root:
		return res
	
	for i in root.get_children():
		res.append(i.get_text(0))
	
	return res

# WARNING: Some paths may be inaccurate.
func get_paths() -> Array:
	var res = []
	
	var raw = get_raw_paths()
	var scene_paths = EditorInterface.get_open_scenes()
	
	for name: String in raw:
		if name.begins_with("res://") or name.get_extension() == "godot":
			res.append(name)
			continue
		
		var found = false
		
		for scene_path in scene_paths:
			if scene_path.get_file() == name:
				res.append(scene_path)
				found = true
				break
				
		if found:
			continue
		
		res.append(name)
	
	return res
