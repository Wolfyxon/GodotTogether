@tool
extends GDTNodeWrapper
class_name GDTExternalFileChangeDialog

signal changes_ignored 
signal changes_resaved
signal changes_reloaded

var node: ConfirmationDialog
var tree: Tree

func _wrapper_init() -> void:
	var root_nodes = EditorInterface.get_base_control().get_children()
	
	for i in root_nodes:
		if i is ConfirmationDialog and _check_and_use(i):
			break
	
	if not node:
		GDTUtils.printerr_stack("Failed to find file change window")

# Godot commit: 63b7e027254e6b77b3d1036c89973060fb5be088
# Source: editor/editor_node.cpp line: 9648
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
	
	var cons = dialog.get_signal_connection_list("custom_action")
	
	for con in cons:
		if con and "callable" in con:
			var callable: Callable = con["callable"]
			
			if callable and typeof(callable) == TYPE_CALLABLE:
				if not "_resave_externally_modified_scenes" in callable.get_method():
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

func _cancelled():
	changes_ignored.emit()

func _resaved():
	changes_resaved.emit()
	pass

func _reloaded():
	changes_reloaded.emit()

func ignore_and_resave() -> void:
	node.custom_action.emit("resave")

func ignore_without_saving() -> void:
	node.hide()

func reload() -> void:
	node.confirmed.emit()

func get_paths() -> Array:
	var res = []
	var root = tree.get_root()
	
	if not root:
		return res
	
	for i in root.get_children():
		res.append(i.get_text(0))
	
	return res
