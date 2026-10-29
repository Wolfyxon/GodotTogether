@tool
extends GDTExternalChangeDialogBase
class_name GDTExternalFileChangeDialog

func _wrapper_init() -> void:
	_acquire_node()
	
	if not node: 
		return
	
	_setup_signals()

func _check_dialog(dialog: ConfirmationDialog) -> bool:
	var cons = dialog.get_signal_connection_list("custom_action")
	
	var con_found = false
	
	for con in cons:
		if con and "callable" in con:
			var callable: Callable = con["callable"]
			
			if callable and typeof(callable) == TYPE_CALLABLE:
				if callable.get_method().contains("_resave_externally_modified_scenes"):
					con_found = true
					break
	
	if not con_found:
		return false
	
	return true

func _acquire_node() -> void:
	var nodes = EditorInterface.get_base_control().get_children()
	
	for i in nodes:
		if i is ConfirmationDialog and _check_and_use(i):
			break
	
	if not node:
		GDTUtils.printerr_stack("Failed to find file change window")
