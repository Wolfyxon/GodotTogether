## Class for wrapping Godot editor elements that aren't exposed to the
## plugin API.

@abstract
extends RefCounted
class_name GDTInternalWrapper

func _init() -> void:
	_wrapper_init()

func _wrapper_init() -> void:
	pass

static func get_editor_node(cls: String) -> Node:
	var root = EditorInterface.get_base_control().get_tree().root
	var node = GDTUtils.get_descendant_with_class(root, cls)
	
	if not node:
		printerr("Node with class '%s' not found in editor interface" % cls)
	
	return node

static func get_editor_nodes(cls: String) -> Array:
	var root = EditorInterface.get_base_control().get_tree().root
	return GDTUtils.get_descendants_with_class(root, cls)
