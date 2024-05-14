## A class for making editor plugins with more options than regular [EditorPlugin] and also.
## some additional utilities. [br]
## Wiki can be found at [url]https://github.com/Wolfyxon/godot-BetterEditorPlugin/wiki[/url]
## [codeblock]
## @tool
## extends BetterEditorPlugin 
## func _enter_tree():
##     # Code executed when the plugin gets enabled
##     pass
## func _exit_tree():
##     # Code executed when the plugin gets disabled
##     pass
## [/codeblock] [br]
## Have fun!

@tool
extends EditorPlugin
class_name BetterEditorPlugin_GodotTogether
# Commit version: 78aaca68033b0d9b4a035d9dbee1c3e574b055f9
# This is a bundled version of BetterEditorPlugin

signal filesystem_dir_context_menu_opened
signal filesystem_file_context_menu_opened
signal filesystem_context_menu_item_clicked(item:PopupMenuItem)

signal node_context_menu_item_clicked(item:PopupMenuItem)

enum PATH_TYPE {Nonexistent, File, Directory}

var fs_context_menu:PopupMenu
var scene_tree_dock:VBoxContainer
var editor_3d_cam:Camera3D

var _registered_fs_dir_options = [
#	{
#		label: "option label"
#		icon: Texture2D or null
#		strID: "User specified or generated option ID"
#	}
]
var _registered_fs_file_options = [
#	{
#		label: "option label"
#		icon: Texture2D or null
#		strID: "User specified or generated option ID"
#		allowed_types: ["allowed","file","extensions.","example:","png"] (allows all if empty)
#	}
]
var _registered_node_options = [
#	{
#		label: "option label"
#		icon: Texture2D or null
#		strID: "User specified or generated option ID"
#		allowed_classes: [] (allows all if empty)
#	}
]

## A class for easier dealing with items in [PopupMenu]. 
class PopupMenuItem:
	
	## The source [PopupMenu]
	var popup_menu:PopupMenu
	## Item index
	var index:int

	func _init(source:PopupMenu, index:int):
		popup_menu = source
		self.index = index
	
	## Returns the item ID at the current index
	func get_id() -> int: return popup_menu.get_item_id(index)
	## Returns the item index
	func get_index() -> int: return index
	## Returns the item text
	func get_text() -> String: return popup_menu.get_item_text(index)
	## Returns the item icon texture (if present)
	func get_icon() -> Texture2D: return popup_menu.get_item_icon(index)
	## Returns the item metadata (if present)
	func get_metadata(): return popup_menu.get_item_metadata(index)
	## Returns the item String ID used for identifying the options. Applies only to custom options.
	func get_string_id() -> String:
		var meta = get_metadata()
		if meta==null or !typeof(meta) == TYPE_DICTIONARY: return ""
		return meta["strID"]
	## Checks if the item is disabled
	func is_disabled() -> bool: return popup_menu.is_item_disabled(index)
	
	## Sets the item text
	func set_text(text:String): popup_menu.set_item_text(index,text)
	## Sets the item icon texture
	func set_icon(icon:Texture2D): popup_menu.set_item_icon(index,icon)
	## Sets item metadata. WARNING: this might remove the String ID
	func set_metadata(meta): popup_menu.set_item_metadata(index,meta)
	## Sets the item ID. Proceed with caution as this often causes issues
	func set_id(id:int): popup_menu.set_item_id(index, id)
	## Sets if the item is disabled or not
	func set_disabled(disabled:bool): popup_menu.set_item_disabled(index,disabled)
	## Disables the item
	func disable(): set_disabled(true)
	## Enables the item
	func enable(): set_disabled(false)
	
# ============== Private methods ============== #
# Please do not overwrite these methods or this class won't work properly

# _enter_tree and _exit_tree can't be used because they will be overwritten by the extended classes.
# _notification will always fire no matter if it's overwritten. 
func _notification(what):
	if what == NOTIFICATION_ENTER_TREE:
		get_editor_3d_camera()
		get_fs_context_menu()
		get_scene_tree_dock()
		
		fs_context_menu.about_to_popup.connect(_fs_context_menu_opened)
		forward_popup_menu_item_signal(get_fs_context_menu(),filesystem_context_menu_item_clicked)
		
		forward_popup_menu_item_signal(get_node_context_menu(),node_context_menu_item_clicked)
		get_node_context_menu().about_to_popup.connect(_scene_tree_context_menu_opened)
	
	if what == NOTIFICATION_EXIT_TREE:
		pass

func _allow_node_option(nodes:Array[Node], allowed_classes:Array, strict:=false) -> bool:
	if allowed_classes.size()==0: return true
	for i in nodes:
		if strict and !(i.get_class() in allowed_classes): return false
		if !strict:
			var allow = false
			for c in allowed_classes:
				if i.is_class(c):
					allow = true
					break
			if !allow: return false
			
	return true

func _scene_tree_context_menu_opened():
	for i in _registered_node_options:
		if _allow_node_option(get_selected_nodes(), i["allowed_classes"]):
			var label = i["label"]
			var id = i["strID"]
			if id == "": id = label
			if ("icon" in i) and i["icon"]:
				add_node_context_icon_option(label,i["icon"],{"strID":id})
			else:
				add_node_context_option(label,{"strID":id})
	

func _allow_file_option(file_names:PackedStringArray, allowed_types:PackedStringArray) -> bool:
	if allowed_types.size()==0: return true
	
	for i in file_names:
		if !( get_file_extension(i) in allowed_types ): return false
	
	return true

func _fs_context_menu_opened():

	if is_fs_selected_path_file_or_dir() == PATH_TYPE.Directory:
		filesystem_dir_context_menu_opened.emit()
		for i in _registered_fs_dir_options:
			var label = i["label"]
			var id = i["strID"]
			if id == "": id = label
			if ("icon" in i) and i["icon"]:
				add_fs_context_menu_icon_item(i["label"],i["icon"],{"strID":id})
			else:
				add_fs_context_menu_item(i["label"],{"strID":id})
		
	if is_fs_selected_path_file_or_dir() == PATH_TYPE.File:
		filesystem_file_context_menu_opened.emit()
		for i in _registered_fs_file_options:
			if _allow_file_option(get_fs_selected_names(),i["allowed_types"]):
				var label = i["label"]
				var id = i["strID"]
				if ("icon" in i) and i["icon"]:
					add_fs_context_menu_icon_item(i["label"],i["icon"],{"strID":id})
				else:
					add_fs_context_menu_item(i["label"],{"strID":id})

func _popup_menu_index_clicked_func_forward(index:int, popupmenu:PopupMenu, callable:Callable):
	var item = PopupMenuItem.new(popupmenu, index)
	callable.call(item)

func _popup_menu_index_clicked_signal_forward(index:int, popupmenu:PopupMenu, signal_:Signal):
	var item = PopupMenuItem.new(popupmenu, index)
	signal_.emit(item)

func _signal_forward(source:Signal, target:Signal):
	target.emit()

# ============== User methods ============== #

## Emits another signal when a specified signal is emitted. Currently works only with signals without any arguments
func forward_signal(source_signal:Signal, target_signal:Signal):
	source_signal.connect(_signal_forward.bind(target_signal))

## Converts a [PopupMenu] index_pressed signal result into a [PopupMenuItem] with all required info then calls the specified function.
func connect_popup_menu_item_signal(popupmenu:PopupMenu, callable:Callable):
	popupmenu.index_pressed.connect( _popup_menu_index_clicked_func_forward.bind(popupmenu, callable) )

## Converts a [PopupMenu] index_pressed signal result into a [PopupMenuItem] with all required info then emits the specified signal.
func forward_popup_menu_item_signal(popupmenu:PopupMenu, signal_:Signal):
	popupmenu.index_pressed.connect( _popup_menu_index_clicked_signal_forward.bind(popupmenu, signal_) )

## Returns the current context (right click) menu in the FileSystem dock.
func get_fs_context_menu() -> PopupMenu:
	if fs_context_menu: return fs_context_menu
	var dock:FileSystemDock = get_editor_interface().get_file_system_dock()
	var menus = get_children_by_class_name(dock,"PopupMenu")
	if menus.size()==0: return
	var menu = menus[menus.size()-1]
	fs_context_menu = menu
	return menu

## Permanentaly (unless the plugin is disabled) adds an option to the directory context (right click) menu in the FileSystem dock
func register_fs_dir_context_option(label:String, id:String="", icon:Texture2D=null):
	if id == "": id = label
	_registered_fs_dir_options.append(
		{
			"label": label,
			"icon": icon,
			"strID": id
		}
	)

## Permanentaly (unless the plugin is disabled) adds an option to the file context (right click) menu in the FileSystem dock
func register_fs_file_context_option(label:String, id:String="", icon:Texture2D=null, allowed_types:PackedStringArray=[]):
	if id == "": id = label
	_registered_fs_file_options.append(
		{
			"label": label,
			"icon": icon,
			"strID": id,
			"allowed_types": allowed_types
		}
	)

## Adds a button to the FileSystem dock context (right click) menu. Returns index of the created item
func add_fs_context_menu_item(label:String, meta=null) -> int:
	var id = get_id_for_new_popup_menu_item(get_fs_context_menu())
	get_fs_context_menu().add_item(label,id)
	var idx = id-1#get_fs_context_menu().get_item_index(id)
	get_fs_context_menu().set_item_metadata(idx,meta)
	return idx

## Adds a button with an icon to the FileSystem dock context (right click) menu. Returns index of the created item
func add_fs_context_menu_icon_item(label:String, icon:Texture2D, meta=null) -> int:
	var id = get_id_for_new_popup_menu_item(get_fs_context_menu())
	get_fs_context_menu().add_icon_item(icon,label,id)
	var idx = id-1#get_fs_context_menu().get_item_index(id)
	get_fs_context_menu().set_item_metadata(idx,meta)
	return idx

## Adds a check button to the FileSystem dock context (right click) menu. Returns index of the created item
func add_fs_context_menu_check_item(label:String, meta=null) -> int:
	var id = get_id_for_new_popup_menu_item(get_fs_context_menu())
	get_fs_context_menu().add_check_item(label,id)
	var idx = id-1#get_fs_context_menu().get_item_index(id)
	get_fs_context_menu().set_item_metadata(idx,meta)
	return idx

## Adds a check button with an icon to the FileSystem dock context (right click) menu
func add_fs_context_menu_icon_check_item(label:String, icon:Texture2D):
	get_fs_context_menu().add_icon_check_item(icon, label, get_id_for_new_popup_menu_item(get_fs_context_menu()))

## Gets the file tree in the FileSystem dock.
func get_fs_tree() -> Tree:
	return get_first_descendant_by_class_name(get_editor_interface().get_file_system_dock(),"Tree",true)

## Gets the currently selected [TreeItem] in the FileSystem dock
func get_fs_selected_item() -> TreeItem:
	return get_fs_tree().get_selected()
	
## Returns selected [TreeItem]s in the FileSystem dock
func get_fs_selected_items() -> Array[TreeItem]: 
	return get_selected_tree_items(get_fs_tree())

## Returns the name of the currently selected file or directory in the FileSystem dock
func get_fs_selected_name() -> String:
	var item:TreeItem = get_fs_selected_item()
	if !item: return ""
	return item.get_text(0)
	
## Returns all names of the currently selected files and directories in the FileSystem dock.
func get_fs_selected_names() -> Array[String]:
	var res:Array[String] = []
	for i in get_fs_selected_items():
		res.append(i.get_text(0))
	return res

## Returns the path to the currently selected file or directory in the FileSystem dock.
func get_fs_selected_path() -> String:
	var item = get_fs_selected_item()
	if !item: return ""
	return item.get_metadata(0)

## Returns paths to all selected files and directories in the FileSystem dock
func get_fs_selected_paths() -> Array[String]:
	var res:Array[String] = []
	for i in get_fs_selected_items():
		res.append(i.get_metadata(0))
	return res

## Checks if the selected entry in the FileSystem dock is a file or directory. See also [method is_file_or_dir]
func is_fs_selected_path_file_or_dir() -> PATH_TYPE:
	var path = get_fs_selected_path()
	if path == "": return PATH_TYPE.Nonexistent
	return is_file_or_dir(path)

## Returns a unexposed class SceneTreeDock. 
func get_scene_tree_dock() -> VBoxContainer:
	if scene_tree_dock: return scene_tree_dock
	var d = get_first_descendant_by_class_name(get_editor_interface().get_base_control(),"SceneTreeDock")
	scene_tree_dock = d
	return d

## Returns a context (right click) [PopupMenu] of the SceneTreeDock
func get_node_context_menu() -> PopupMenu:
	return get_scene_tree_dock().get_child(15)

## Returns the SceneTreeDock's node [Tree]
func get_scene_node_tree() -> Tree:
	return get_first_child_by_class_name(get_first_descendant_by_class_name(get_scene_tree_dock(),"SceneTreeEditor"),"Tree")

## Returns the path of the first selected [Node]
func get_selected_node_path() -> NodePath:
	var sel = get_scene_node_tree().get_selected()
	if not sel: return ""
	return sel.get_metadata(0)

## Returns the first selected [Node]
func get_selected_node() -> Node:
	return get_node_or_null(get_selected_node_path())

## Returns paths of the selected [Node]s
func get_selected_node_paths() -> Array[NodePath]:
	var res:Array[NodePath] = []
	for i in get_selected_tree_items(get_scene_node_tree()):
		res.append(i.get_metadata(0))
		
	return res
	
## Returns the selected [Node]s
func get_selected_nodes() -> Array[Node]:
	var res:Array[Node] = []
	for i in get_selected_node_paths():
		var n = get_node_or_null(i)
		if n: res.append(n)

	return res

## Permanentaly (unless the plugin is disabled) adds an option to the directory context (right click) menu in the Scene node tree dock
func register_node_context_option(label:String, id:String="", icon:Texture2D=null, allowed_classes:Array=[]):
	_registered_node_options.append({
		"label": label,
		"strID": id,
		"icon": icon,
		"allowed_classes": allowed_classes
	})

## Adds a button to the Scene dock context (right click) menu. Returns index of the created item
func add_node_context_option(label:String, meta=null) -> int:
	var id = get_id_for_new_popup_menu_item(get_node_context_menu())
	var idx = id - 1
	get_node_context_menu().add_item(label, id)
	get_node_context_menu().set_item_metadata(idx, meta)
	return idx

## Adds a button with an icon to the Scene dock context (right click) menu. Returns index of the created item
func add_node_context_icon_option(label:String, icon:Texture2D, meta=null) -> int:
	var id = get_id_for_new_popup_menu_item(get_node_context_menu())
	var idx = id - 1
	get_node_context_menu().add_icon_item(icon, label, id)
	get_node_context_menu().set_item_metadata(idx, meta)
	return idx

## Adds a check button to the Scene dock context (right click) menu. Returns index of the created item
func add_node_context_check_option(label:String, meta=null) -> int:
	var id = get_id_for_new_popup_menu_item(get_node_context_menu())
	var idx = id - 1
	get_node_context_menu().add_check_item(label, id)
	get_node_context_menu().set_item_metadata(idx, meta)
	return idx

## Adds a check button with an icon to the Scene dock context (right click) menu
func add_node_context_icon_check_option(label:String, icon:Texture2D, meta=null) -> int:
	var id = get_id_for_new_popup_menu_item(get_node_context_menu())
	var idx = id - 1
	get_node_context_menu().add_icon_check_item(icon, label, id)
	get_node_context_menu().set_item_metadata(idx, meta)
	return idx

## Returns the editor's [Camera3D]. Unfortunately, getting the editor's [Camera2D] isn't possible because it doesn't even use it.
func get_editor_3d_camera() -> Camera3D:
	if editor_3d_cam: return editor_3d_cam
	var scene = get_editor_interface().get_edited_scene_root()
	var cam:Camera3D
	for i in get_descendants_by_class_name(get_editor_interface().get_base_control(),"Camera3D"):
		if !scene or !(i in get_descendants(scene)): 
			cam = i
			break
	editor_3d_cam = cam
	return cam

## Gets a editor from the EditorMainScreen.
func get_editor_in_main_screen(editor:String) -> Node:
	return get_first_child_by_class_name(get_editor_interface().get_editor_main_screen(),editor)

## Returns an unexposed CanvasItemEditor
func get_canvas_item_editor() -> Node:
	return get_editor_in_main_screen("CanvasItemEditor")

## Returns an unexposed Node3DEditor
func get_node_3d_editor() -> VBoxContainer:
	return get_editor_in_main_screen("Node3DEditor")

## Returns an unexposed CPUParticles3DEditor
func get_cpu_particles_3d_editor() -> Control:
	return get_editor_in_main_screen("CPUParticles3DEditor")

## Returns an unexposed GPUParticles3DEditor
func get_gpu_particles_3d_editor() -> Control:
	return get_editor_in_main_screen("GPUParticles3DEditor")

## Returns an unexposed MeshInstance3DEditor
func get_mesh_instance_3d_editor() -> Control:
	return get_editor_in_main_screen("MeshInstance3DEditor")

## Returns an unexposed MeshLibraryEditor
func get_mesh_library_editor() -> Control:
	return get_editor_in_main_screen("MeshLibraryEditor")

## Returns an unexposed MeshLibraryEditor
func get_multi_mesh_editor() -> Control:
	return get_editor_in_main_screen("MeshLibraryEditor")
	
## Returns an unexposed Skeleton2DEditor
func get_skeleton_2d_editor() -> Control:
	return get_editor_in_main_screen("Skeleton2DEditor")

## Returns an unexposed Sprite2DEditor
func get_sprite_2d_editor() -> Control:
	return get_editor_in_main_screen("Sprite2DEditor")

## Returns an unexposed NavigationMeshEditor
func get_navigation_mesh_editor() -> Control:
	return get_editor_in_main_screen("NavigationMeshEditor")

## Returns the edited scene container which is a [SubViewport]. It doesn't require a scene to be open.
func get_scene_sub_viewport() -> SubViewport:
	for i in get_descendants_by_class_name(get_canvas_item_editor(),"SubViewport"):
		if !get_editor_interface().get_edited_scene_root() or (i == get_editor_interface().get_edited_scene_root().get_parent()):
			return i
	push_error("Failed to get the scene SubViewport. This is not supposed to happen")
	return null

## Returns the "camera" position in the 2D scene editor.
func get_2d_transform() -> Transform2D:
	return get_scene_sub_viewport().get_screen_transform()

## Gets the currently open [ScriptEditorBase]
func get_current_script_editor() -> ScriptEditorBase:
	for i in get_editor_interface().get_script_editor().get_open_script_editors():
		if i.is_visible_in_tree(): return i
	return null

## Gets the [CodeEdit] text editor from the currently open [ScriptEditorBase]
func get_code_edit_from_current_script_editor() -> CodeEdit:
	var editor = get_current_script_editor()
	if !editor: return null
	return get_code_edit_from_script_editor(editor)

# ============== Static methods ============== #

## Gets the [CodeEdit] text editor from the specified [ScriptEditorBase]
static func get_code_edit_from_script_editor(script_editor:ScriptEditorBase) -> CodeEdit:
	return get_first_descendant_by_class_name(script_editor,"CodeEdit")

## Manually specified IDs sometimes cause problems such as the wrong option being detected as pressed. This uses the index.
static func get_id_for_new_popup_menu_item(popupmenu:PopupMenu) -> int:
	return popupmenu.item_count+1

## Returns a String type name of a TYPE enum. Example [code]print( type_name( typeof("hello") ) )[/code] will print [code]String[/code]
static func type_name(type:int) -> String:
	match type:
		TYPE_AABB: return "AABB"
		TYPE_ARRAY: return "Array"
		TYPE_BASIS: return "Basis"
		TYPE_BOOL: return "Bool"
		TYPE_CALLABLE: return "Callable"
		TYPE_COLOR: return "Color"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_FLOAT: return "float"
		TYPE_INT: return "int"
		TYPE_MAX: return "max"
		TYPE_NIL: return "null"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_OBJECT: return "Object"
		TYPE_PLANE: return "Plane"
		TYPE_PROJECTION: return "Projection"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_RECT2: return "Rect2"
		TYPE_RECT2I: return "Rect2i"
		TYPE_RID: return "RID"
		TYPE_SIGNAL: return "Signal"
		TYPE_STRING: return "String"
		TYPE_STRING_NAME: return "StringName"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_VECTOR4: return "Vector4"
		TYPE_VECTOR4I: return "Vector4i"
		# Arrays
		TYPE_PACKED_BYTE_ARRAY: return "Array[byte]"
		TYPE_PACKED_COLOR_ARRAY: return "Array[Color]"
		TYPE_PACKED_FLOAT32_ARRAY: return "Array[float32]"
		TYPE_PACKED_FLOAT64_ARRAY: return "Array[float64]"
		TYPE_PACKED_INT32_ARRAY: return "Array[int32]"
		TYPE_PACKED_INT64_ARRAY: return "Array[int64]"
		TYPE_PACKED_STRING_ARRAY: return "Array[String]"
		TYPE_PACKED_VECTOR2_ARRAY: return "Array[Vector2]"
		TYPE_PACKED_VECTOR3_ARRAY: return "Array[Vector3]"

	return "Unknown"

## Returns a String type name of a value. Example [code]print( string_typeof("hello") )[/code] will print [code]String[/code]
static func string_typeof(value) -> String: return type_name(typeof(value))

## Returns all selected [TreeItem]s in a [Tree]
static func get_selected_tree_items(tree:Tree) -> Array[TreeItem]:
	var res:Array[TreeItem] = []
	var first = tree.get_selected()
	var next = tree.get_next_selected(null)
	
	while next:
		res.append(next)
		next = tree.get_next_selected(next)
	
	return res

## A recursive function that returns all nodes in tree of selected node.
static func get_descendants(node:Node,include_internal:=true) -> Array[Node]:
	var res:Array[Node] = []
	
	for i in node.get_children(include_internal):
		if i.get_child_count(include_internal) != 0: res.append_array(get_descendants(i,include_internal))
		res.append(i)
	
	return res

## Returns all values from given array matching the specified type.
static func get_values_by_type(array:Array, type:int) -> Array:
	var res = []
	for i in array:
		if type == typeof(i): res.append(i)
	return res

## Returns all [Object]s and classes extending them such as [Node]s from the given array, matching (if [code]strict[/code] is true) the given class name or extending it (if [code]strict[/code] is false) 
static func get_objects_by_class_name(array:Array, class_name_:String, strict:=false) -> Array:
	var res = []
	for i in array:
		if i is Object:
			if strict: 
				if i.get_class() == class_name_: res.append(i)
			else:
				if i.is_class(class_name_): res.append(i)
		else:
			push_error(str(i)+" is not an Object. It's an "+string_typeof(i)+". Consider using get_values_by_type()")
	return res

## Returns the first [Object] or a class extending it such as [Node] from the given array, matching (if [code]strict[/code] is true) the given class name or extending it (if [code]strict[/code] is false) 
static func get_first_object_by_class_name(array:Array, class_name_:String, strict:=false) -> Object:
	for i in array:
		if i is Object:
			if strict: 
				if i.get_class() == class_name_: return i
			else:
				if i.is_class(class_name_): return i
		else:
			push_error(str(i)+" is not an Object. It's an "+string_typeof(i)+". Consider using get_values_by_type()")
	return null
	

## Returns all children [Node]s from the given array, matching (if [code]strict[/code] is true) the given class name or extending it (if [code]strict[/code] is false) 
static func get_children_by_class_name(node:Node, class_name_:String, strcit:=false,include_internal:=true) -> Array:
	return get_objects_by_class_name(node.get_children(include_internal),class_name_,strcit)
	
## Returns all descendant [Node]s from the given array, matching (if [code]strict[/code] is true) the given class name or extending it (if [code]strict[/code] is false) 
static func get_descendants_by_class_name(node:Node, class_name_:String, strcit:=false,include_internal:=true) -> Array:
	return get_objects_by_class_name(get_descendants(node,include_internal),class_name_,strcit)
	
## Returns the first child [Node] from the given array, matching (if [code]strict[/code] is true) the given class name or extending it (if [code]strict[/code] is false) 
static func get_first_child_by_class_name(node:Node, class_name_:String, strcit:=false,include_internal:=true) -> Node:
	return get_first_object_by_class_name(node.get_children(include_internal),class_name_,strcit)
	
## Returns the first descendant [Node] from the given array, matching (if [code]strict[/code] is true) the given class name or extending it (if [code]strict[/code] is false) 
static func get_first_descendant_by_class_name(node:Node, class_name_:String, strcit:=false,include_internal:=true) -> Node:
	return get_first_object_by_class_name(get_descendants(node,include_internal),class_name_,strcit)
	
## Checks if a directory exists at the given local or absolute path.
static func dir_exists(path:String) -> bool:
	if path == "res://": return true
	return DirAccess.open(path).dir_exists(path)

## Checks if a file exists at the given local or absolute path.
static func file_exists(path:String) -> bool:
	if path == "res://": return false
	return DirAccess.open(path.get_base_dir()).file_exists(path)

## Checks if a file or directory exists at the given local or absolute path.
static func path_exists(path:String) -> bool:
	return file_exists(path) or dir_exists(path)

## Determines is a file or a directory exists at the given path. Returns [enum PATH_TYPE.Nonexistent] if nothing exists.
static func is_file_or_dir(path:String) -> PATH_TYPE:
	if file_exists(path): return PATH_TYPE.File
	if dir_exists(path): return PATH_TYPE.Directory
	return PATH_TYPE.Nonexistent

## Returns a file extension from the specified file name
static func get_file_extension(file_name:String) -> String:
	var split = file_name.split(".")
	if split.size()<2: return file_name
	return split[split.size()-1]
	
	
