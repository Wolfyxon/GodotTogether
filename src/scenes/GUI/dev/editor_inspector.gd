@tool
extends VBoxContainer

@onready var tree_selector = $treeSelection

var main: GodotTogether = null
var tree_nodes = []

func _ready() -> void:
	while get_tree() and not main:
		await get_tree().process_frame
	
	register_loadable_node(GDTUtils.get_root(), "Root")
	register_loadable_node(EditorInterface.get_base_control(), "Base control")
	register_loadable_node(EditorInterface.get_script_editor(), "Script editor")
	register_loadable_node(EditorInterface.get_file_system_dock(), "FS dock")
	register_loadable_node(EditorInterface.get_inspector(), "Inspector")

func register_loadable_node(node: Node, display_name: String) -> void:
	tree_selector.add_item(display_name)
	tree_nodes.append(node)

func _on_btn_load_tree_pressed() -> void:
	var node = tree_nodes[tree_selector.selected]
	
	if not node:
		printerr("Node is null")
		return
	
	main.gui.scene_tree_editor.load_tree(node)
