extends GDTComponent
class_name GDTDebug

func _ready() -> void:
	report_ready()

static func dump_node_classes(root: Node = null, names := []) -> void:
	if not root:
		root = EditorInterface.get_base_control()

	if not root.get_class() in names:
		print(root.get_class())
		names.append(root.get_class())
	
	for i in root.get_children():
		dump_node_classes(i, names)
