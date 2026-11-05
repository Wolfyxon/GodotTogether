extends GDTNodeWrapper
class_name GDTSceneTreeEditor

const DEBUG_NODE_PATH_META = "_gdt_node_path"

var node: Control
var _tree_control: Tree

func _wrapper_init() -> void:
	node = get_editor_node("SceneTreeEditor")
	if not node: return
	
	var tree = get_tree_control()
	tree.cell_selected.connect(_tree_item_selected)
	tree.item_activated.connect(_tree_item_selected)

func _tree_item_selected():
	var tree = get_tree_control()
	if not tree: return
	
	var item = tree.get_selected()
	if not item: return
	
	if not item.has_meta(DEBUG_NODE_PATH_META):
		return
	
	var n = GDTUtils.get_root().get_node_or_null(item.get_meta(DEBUG_NODE_PATH_META))
	EditorInterface.edit_node(n)

func get_tree_control() -> Tree:
	if _tree_control:
		return _tree_control
		
	_tree_control = GDTUtils.get_descendant_with_class(node, "Tree")
	return _tree_control

func get_tree_item_matching_node(match_node: Node) -> TreeItem:
	var scene = GDTUtils.get_node_scene(match_node)
	if not scene: return
	
	var path = scene.get_path_to(match_node)
	return get_tree_item_at_path(path)

func clear_colors(root: TreeItem = null) -> void:
	if not root:
		root = get_tree_control().get_root()
	
	if not root:
		return
	
	root.clear_custom_bg_color(0)
	
	for i in root.get_children():
		if not i: continue
		clear_colors(i)

func clear_matching_colors(color: Color, root: TreeItem = null) -> void:
	if not root:
		root = get_tree_control().get_root()
	
	if not root:
		return
	
	if root.get_custom_bg_color(0) == color:
		root.clear_custom_bg_color(0)
	
	for i in root.get_children():
		if not i: continue
		clear_matching_colors(color, i)

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

# Only for debugging purposes!
func load_tree(root_node: Node, tree_root: TreeItem = null) -> void:
	if not root_node or root_node.is_queued_for_deletion():
		GDTUtils.printerr_stack("root node is null or deleted")
		return
		
	if not tree_root:
		tree_root = get_tree_control().get_root()
	
	clear_tree(tree_root)
	load_node_to_item(tree_root, root_node)
	
	for i in root_node.get_children():
		var item = tree_root.create_child()
		load_tree(i, item)

func clear_tree(tree: TreeItem) -> void:
	for i in tree.get_children():
		tree.remove_child(i)

func load_node_to_item(item: TreeItem, load_node: Node) -> void:
	item.set_text(0, load_node.name)
	
	var path = GDTUtils.get_root().get_path_to(load_node)
	item.set_meta(DEBUG_NODE_PATH_META, path)
	
