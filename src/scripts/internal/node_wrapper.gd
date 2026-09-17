## Class for wrapping Godot editor elements that aren't exposed to the
## plugin API.

@abstract
extends RefCounted
class_name GDTNodeWrapper

func _init() -> void:
	_wrapper_init()
	
	get_wrapped_node()

@abstract
func _wrapper_init() -> void

# Not using a global property to preserve type hints of extended classes
func get_wrapped_node() -> Node:
	if not "node" in self:
		GDTUtils.printerr_stack("Wrapper should have 'node' property")
		return
	
	return get("node")

static func get_editor_node(cls: String) -> Node:
	var root = EditorInterface.get_base_control()
	var node = GDTUtils.get_descendant_with_class(root, cls)
	
	if not node:
		printerr("Node with class '%s' not found in editor interface" % cls)
	
	return node
