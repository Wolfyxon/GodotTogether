@abstract
extends GDTInternalWrapper
class_name GDTNodeWrapper

func _init() -> void:
	super()
	get_wrapped_node()

@abstract
func _wrapper_init() -> void

# Not using a global property to preserve type hints of extended classes
func get_wrapped_node() -> Node:
	if not "node" in self:
		GDTUtils.printerr_stack("Wrapper should have 'node' property")
		return
	
	return get("node")
