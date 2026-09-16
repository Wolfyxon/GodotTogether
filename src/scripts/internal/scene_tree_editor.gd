extends GDTNodeWrapper
class_name GDTSceneTreeEditor

var node: Control
var _tree_control: Tree

func _wrapper_init() -> void:
	node = get_editor_node("SceneTreeEditor")
	if not node: return

func get_tree_control() -> Tree:
	if _tree_control:
		return _tree_control
		
	_tree_control = GDTUtils.get_descendant_with_class(node, "Tree")
	return _tree_control

func get_tree_item_matching_node(node: Node) -> TreeItem:
	var scene = GDTUtils.get_node_scene(node)
	if not scene: return
	
	var path = scene.get_path_to(node)
	return get_tree_item_at_path(path)

func get_tree_item_at_path(path: String, root: TreeItem = null) -> TreeItem:
	if not root:
		root = get_tree_control().get_root()
	
	var path_split = path.split("/")
	var current = root
	
	for name in path_split:
		if name == ".":
			continue
		
		var found = false
		
		for i in current.get_children():
			if i.get_text(0) == name:
				current = i
				found = true
				break
		
		if not found:
			return
	
	return current
