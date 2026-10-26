@tool
extends GDTNodeWrapper
class_name GDTEditorNode

var node: Node = null

func _wrapper_init() -> void:
	node = get_editor_node("EditorNode")

# editor_node.cpp line 1091
# commit: 63b7e027254e6b77b3d1036c89973060fb5be088
# _scan_external_changes() is only called upon NOTIFICATION_APPLICATION_FOCUS_IN
# There's no other way to check them
func force_filesystem_scan() -> void:
	var focused = DisplayServer.window_is_focused()
	
	node.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN, true)
	
	if not focused:
		node.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
