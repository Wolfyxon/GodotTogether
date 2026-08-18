extends GDTComponent
class_name GDTNodeSync

enum ResourceType {
	LOCAL,
	FILE
}

const IGNORED_PROPERTY_USAGE_FLAGS := [
	PROPERTY_USAGE_NONE,
	PROPERTY_USAGE_GROUP,
	PROPERTY_USAGE_CATEGORY,
	PROPERTY_USAGE_SUBGROUP,
	PROPERTY_USAGE_INTERNAL,
	PROPERTY_USAGE_READ_ONLY
]

const IGNORED_PROPERTIES: Dictionary = {
	"Node": [
		"owner",
		"multiplayer"
	],
	"Control": [
		"offset_left", "offset_right",
		"offset_top", "offset_bottom"
	],
	"Node2D": [
		"global_position",
		"global_rotation"
	],
	"Node3D": [
		"transform",
		"global_transform",
		"global_basis",
		"global_position",
		"global_rotation",
		"global_rotation_degrees"
	],
	"Resource": [
		#"resource_path"
	]
}

var change_timer = Timer.new()
var rescan_timer = Timer.new()

# Using dictionary without objects for better performance
var node_data_dict = {
	# [node]: {
	#	"hashes": {
	#		[property]: hash,
	#		[object]: {
	#			".": hash of object instance,
	#			[property]: hash
	#		}
	#	},
	#	"last_name": name,
	#	"last_path": path
	# } 
}

const SETGET_PROPERTIES = {
	"Control": {
		"theme_override_colors/?": {
			"reset": {
				"func": "remove_theme_color_override",
				"args": ["?"]
			}
		},
		"theme_override_constants/?": {
			"reset": {
				"func": "remove_theme_constant_override",
				"args": ["?"]
			}
		},
		"theme_override_fonts/?": {
			"reset": {
				"func": "remove_theme_font_override",
				"args": ["?"]
			}
		},
		"theme_override_font_sizes/?": {
			"default": "get_theme_default_font_size",
			
			"reset": {
				"func": "remove_theme_font_size_override",
				"args": ["?"]
			}
		},
		"theme_override_icons/?": {
			"reset": {
				"func": "remove_theme_icon_override",
				"args": ["?"]
			}
		},
		"theme_override_styles/?": {
			"reset": {
				"func": "remove_theme_stylebox_override",
				"args": ["?"]
			}
		}
	}
}

var supressed_nodes = {}
var last_scene_path: String = ""
var always_scan = false # Enables change scanning even when session is inactive
						# Useful in debugging

func _ready() -> void:
	change_timer.wait_time = GDTSettings.get_setting("sync/node_refresh_rate")
	change_timer.timeout.connect(_check_changes)
	add_child(change_timer)
	change_timer.start()
	
	rescan_timer.wait_time = 1
	rescan_timer.timeout.connect(observe_current_scene)
	add_child(rescan_timer)
	rescan_timer.start()
	
	start()

func _check_changes() -> void:
	if not can_sync_nodes(): return
	
	var root := EditorInterface.get_edited_scene_root()
	if not root: return
	
	for node in node_data_dict:
		_check_node(node, root)

# "node" must be untyped to prevent freed nodes from stopping the code
func _check_node(node, root: Node = null) -> void:
	if not is_node_valid(node):
		return
	
	if not root:
		root = EditorInterface.get_edited_scene_root()
	
	if GDTUtils.get_node_scene(node) != root:
		return # Belongs to non-current scene, ignore.
	
	var data = node_data_dict[node]
	
	if not data:
		return
	
	var last_hashes = data["hashes"]
	var new_hashes = get_hash_dict(node)
	var diff = GDTUtils.compare_dicts(last_hashes, new_hashes)
	
	if "name" in diff:
		_node_renamed(node, data["last_path"])
		data["last_path"] = root.get_path_to(node)
		data["last_name"] = node.name
	
	if not diff.is_empty():
		_node_properties_changed(node, diff)
	
	data["hashes"] = new_hashes

func _node_renamed(node: Node, old_path: String) -> void:
	if not can_sync_nodes(): return
	if not is_node_valid(node): return
	
	var scene = GDTUtils.get_node_scene(node)
	
	if scene.scene_file_path.is_empty():
		return
	
	if main.server.is_active():
		server_broadcast_node_rename(old_path, scene.scene_file_path, node.name)
	else:
		_c2s_request_node_rename.rpc_id(1, old_path, scene.scene_file_path, node.name)

func _node_properties_changed(node: Node, property_paths: Array) -> void:
	if not can_sync_nodes(): return
	if not is_node_valid(node): return
	
	var scene = GDTUtils.get_node_scene(node)
	if not scene: return
	
	if scene.scene_file_path.is_empty():
		return
	
	var node_path = scene.get_path_to(node)
	var property_dict = get_select_property_dict(node, property_paths)
	
	if not main.is_session_active():
		return
	
	if main.server.is_active():
		server_broadcast_node_update(node_path, scene.scene_file_path, property_dict)
	else:
		_c2s_request_node_update.rpc_id(1, node_path, scene.scene_file_path, property_dict)

func _node_child_entered_tree(child: Node, parent: Node) -> void:
	# 'owner' is set very late, causing is_node_valid(child) to return false.
	# Do not check it here
	if not is_node_valid(parent): return
	if not can_sync_nodes(): return
	
	if not is_node_observed(parent): return
	if is_node_observed(child): return
	
	var scene = GDTUtils.get_node_scene(parent)
	if not scene: return
	
	child.owner = scene # Godot isn't fast enough
	
	var data_dict = observe_node(child)
	
	# Cursed. TODO: Optimize later
	var prop_list = GDTUtils.compare_dicts(data_dict["hashes"], {})
	var prop_dict = get_select_property_dict(child, prop_list)
	
	var parent_path = scene.get_path_to(parent)
	
	if main.server.is_active():
		server_broadcast_node_add(parent_path, scene.scene_file_path, child.get_class(), prop_dict)
	else:
		_c2s_request_node_add.rpc_id(1, parent_path, scene.scene_file_path, child.get_class(), prop_dict)

func _node_tree_exiting(node: Node) -> void:
	if not is_node_valid(node): return
	if not can_sync_nodes(): return
	
	var scene = EditorInterface.get_edited_scene_root()
	if not scene: return
	
	if not scene.is_ancestor_of(node):
		return
	
	var node_path = scene.get_path_to(node)
	
	if main.server.is_active():
		server_broadcast_node_delete(node_path, scene.scene_file_path)
	else:
		_c2s_request_node_delete.rpc_id(1, node_path, scene.scene_file_path)

func _node_child_order_changed(parent: Node) -> void:
	if not is_node_valid(parent): return
	if is_node_supressed(parent): return
	if not can_sync_nodes(): return
	
	var scene = GDTUtils.get_node_scene(parent)
	if not scene: return
	
	var parent_path = scene.get_path_to(parent)
	
	var names = []
	var children = parent.get_children()
	
	for i in children.size():
		names.append(children[i].name)
	
	if main.server.is_active():
		server_broadcast_reorder_children(parent_path, scene.scene_file_path, names)
	else:
		_c2s_request_node_reorder.rpc_id(1, parent_path, scene.scene_file_path, names)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_node_update(node_path: String, scene_path: String, property_dict: Dictionary) -> void:
	if not main.server.validate_c2s(): 
		return
	
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
	
	var id = multiplayer.get_remote_sender_id()
	
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	server_broadcast_node_update(node_path, scene_path, property_dict, id)
	update_node_properties(node_path, scene_path, property_dict)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_node_rename(old_node_path: String, scene_path: String, new_name: String) -> void:
	if not main.server.validate_c2s(): 
		return
	
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
		
	var id = multiplayer.get_remote_sender_id()
	
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	server_broadcast_node_rename(old_node_path, scene_path, new_name, id)
	rename_node(old_node_path, scene_path, new_name)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_node_add(
	parent_path: String, 
	scene_path: String,
	node_class: String,
	property_dict: Dictionary
) -> void:
	if not main.server.validate_c2s(): 
		return
	
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
	
	var id = multiplayer.get_remote_sender_id()
	
	add_node(parent_path, scene_path, node_class, property_dict)
	server_broadcast_node_add(parent_path, scene_path, node_class, property_dict, id)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_node_delete(node_path: String, scene_path: String) -> void:
	if not main.server.validate_c2s(): 
		return
		
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
	
	var id = multiplayer.get_remote_sender_id()
	
	server_broadcast_node_delete(node_path, scene_path, id)
	delete_node(node_path, scene_path)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_node_reorder(parent_path: String, scene_path: String, ordered_names: Array) -> void:
	if not main.server.validate_c2s(): 
		return
		
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
	
	var id = multiplayer.get_remote_sender_id()
	
	server_broadcast_reorder_children(parent_path, scene_path, ordered_names, id)
	reorder_children(parent_path, scene_path, ordered_names)

@rpc("authority", "call_remote", "reliable")
func update_node_properties(node_path: String, scene_path: String, property_dict: Dictionary) -> void:
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var node = GDTUtils.get_node_in_scene(node_path, scene_path)
	if not node: return
	
	set_node_supressed(node, true)
	
	apply_property_dict(node, property_dict)
	apply_node_data(node)
	
	set_node_supressed(node, false)

@rpc("authority", "call_remote", "reliable")
func rename_node(node_path: String, scene_path: String, new_name: String) -> void:
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var node = GDTUtils.get_node_in_scene(node_path, scene_path)
	if not node: return
		
	set_node_supressed(node, true)
	
	if node in node_data_dict:
		node_data_dict[node]["hashes"]["name"] = hash(new_name)
	
	node.name = new_name
	
	set_node_supressed(node, false)
	
@rpc("authority", "call_remote", "reliable")
func add_node(
	parent_path: String, 
	scene_path: String,
	node_class: String,
	property_dict: Dictionary
) -> void:
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var parent = GDTUtils.get_node_in_scene(parent_path, scene_path)
	
	if not parent: 
		printerr("Parent not found %s in scene %s" % [parent_path, scene_path])
		return
	
	var scene = GDTUtils.get_node_scene(parent)
	
	if not scene: 
		printerr("Scene missing")
		return
	
	if not "name" in property_dict:
		printerr("Missing 'name' in property dict")
		return
	
	if parent.has_node(NodePath(property_dict["name"])):
		return
	
	var new_node = validate_and_create_node(node_class)
	if not new_node: return
	
	set_node_supressed(parent, true)
	set_node_supressed(new_node, true)
	
	apply_property_dict(new_node, property_dict)
	
	parent.add_child(new_node)
	new_node.owner = scene
	
	observe_node(new_node)
	
	set_node_supressed(parent, false)
	set_node_supressed(new_node, false)

@rpc("authority", "call_remote", "reliable")
func delete_node(node_path: String, scene_path: String) -> void:
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
		
	var node = GDTUtils.get_node_in_scene(node_path, scene_path)
	if not node: return
	
	var selection = EditorInterface.get_selection()
	
	if node in selection.get_selected_nodes():
		selection.remove_node(node)
	
	unobserve_node(node)
	node.queue_free()

@rpc("authority", "call_remote", "reliable")
func reorder_children(parent_path: String, scene_path: String, ordered_names: Array) -> void:
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var parent = GDTUtils.get_node_in_scene(parent_path, scene_path)
	if not parent: return
	
	set_node_supressed(parent, true)
	
	for i in ordered_names.size():
		var child = parent.get_node(NodePath(ordered_names[i]))
		if not child: continue
		
		parent.move_child(child, i)
		
	set_node_supressed(parent, false)

func server_broadcast_node_update(node_path: String, scene_path: String, property_dict: Dictionary, sender := 0) -> void:
	main.server.auth_rpc(update_node_properties, [node_path, scene_path, property_dict], [sender])

func server_broadcast_node_rename(node_path: String, scene_path: String, new_name: String, sender := 0) -> void:
	main.server.auth_rpc(rename_node, [node_path, scene_path, new_name], [sender])

func server_broadcast_node_delete(node_path: String, scene_path: String, sender := 0) -> void:
	main.server.auth_rpc(delete_node, [node_path, scene_path], [sender])

func server_broadcast_node_add(
	parent_path: String, 
	scene_path: String,
	node_class: String,
	property_dict: Dictionary,
	sender := 0
) -> void:
	main.server.auth_rpc(add_node, [parent_path, scene_path, node_class, property_dict], [sender])

func server_broadcast_reorder_children(
	parent_path: String, 
	scene_path: String, 
	ordered_names: Array, 
	sender := 0
) -> void:
	main.server.auth_rpc(reorder_children, [parent_path, scene_path, ordered_names], [sender])

func validate_and_create_node(node_class: String) -> Node:
	if not ClassDB.class_exists(node_class):
		printerr("Class '%s' doesn't exist" % node_class)
		return
	
	var node = ClassDB.instantiate(node_class)
	
	if not node:
		printerr("Unable to create clas '%s'" % node_class)
		return
	
	if not node is Node:
		printerr("Class '%s' is not a Node" % node_class)
		return
		
	return node

func ignore_last_changes() -> void:
	var root = EditorInterface.get_edited_scene_root()
	
	if not root:
		return
	
	last_scene_path = root.scene_file_path
	
	for node in node_data_dict:
		apply_node_data(node)

func apply_node_data(node: Node) -> Dictionary:
	var res = get_node_data(node)
	node_data_dict[node] = res
	
	return res

func get_node_data(node: Node) -> Dictionary:
	var scene = GDTUtils.get_node_scene(node)
	
	if not scene:
		printerr("Cannot create data of scene-less node")
		return {}
	
	return {
		"name": node.name,
		"last_path": scene.get_path_to(node),
		"hashes": get_hash_dict(node)
	}

func unobserve_node(node: Node) -> void:
	node_data_dict.erase(node)
	supressed_nodes.erase(node)

func observe_node(node: Node) -> Dictionary:
	if not is_node_valid(node):
		return {}
		
	if node in node_data_dict:
		return node_data_dict[node]
		
	node.child_entered_tree.connect(_node_child_entered_tree.bind(node))
	node.child_order_changed.connect(_node_child_order_changed.bind(node))
	node.tree_exiting.connect(_node_tree_exiting.bind(node))
	
	return apply_node_data(node)

func is_node_observed(node: Node) -> bool:
	if not is_node_valid(node):
		return false
		
	return node in node_data_dict

func set_node_supressed(node: Node, state: bool) -> void:
	if state:
		supressed_nodes.get_or_add(node)
	else:
		supressed_nodes.erase(node)

func is_node_supressed(node: Node) -> bool:
	return supressed_nodes.has(node)

func observe_node_recursive(node: Node) -> void:
	observe_node(node)
	
	for i in node.get_children():
		observe_node_recursive(i)

func observe_current_scene() -> void:
	var scene = EditorInterface.get_edited_scene_root()
	
	if not scene:
		return
		
	observe_node_recursive(scene)

func clear() -> void:
	node_data_dict.clear()
	supressed_nodes.clear()
	
func start() -> void:
	clear()
	ignore_last_changes()
	observe_current_scene()

func can_sync_nodes() -> bool:
	return (
		main != null and
		(always_scan or main.is_session_active()) and
		not change_timer.paused and
		not (main.client.is_active() and not main.client.is_fully_synced) and
		not GDTSettings.get_setting("dev/disable_real_time_node_sync")
	)

static func get_hash_dict(obj: Object, depth := 64) -> Dictionary:
	var res = {}
	fill_hash_dict(res, obj, depth)
	return res

static func fill_hash_dict(res: Dictionary, obj: Object, depth := 64) -> Dictionary:
	for key in get_property_keys(obj):
		var value = obj[key]
		
		if value is Object and depth > 0:
			res[key] = {
				"." = hash(value)
			} 
			fill_hash_dict(res[key], value, depth - 1)
		else:
			res[key] = hash(value)
		
	return res

static func get_select_property_dict(obj: Object, paths: Array) -> Dictionary:
	var res = {}
	
	for path: String in paths:
		var true_path = path.replace(GDTUtils.DICT_PATH_SEPARATOR + ".", "")
		var is_setget = is_setget_property(obj, path)
		
		var value = null
		
		if is_setget:
			value = get_setget_property(obj, path)
		else:
			value = GDTUtils.get_nested(obj, true_path)
		
		if value is Resource:
			value = encode_resource(value)
		
		if value == null and path.contains("/") and not is_setget:
			if path.contains("/") and not path.ends_with("."):
				push_error("Setget property not implemented: %s: %s" % [obj.get_class(), path])
			
		res[true_path] = value
	
	return res

static func apply_property_dict(obj: Object, dict: Dictionary) -> void:
	for path in dict.keys():
		var value = dict[path]
		
		if is_encoded_resource(value):
			value = decode_resource(value)
		
		if is_setget_property(obj, path):
			set_setget_property(obj, path, value)
		else:
			GDTUtils.set_nested(obj, path, value)

static func get_setget_properties_of_class(cls_name: String) -> Variant:
	if cls_name in SETGET_PROPERTIES:
		return SETGET_PROPERTIES[cls_name] 
	
	for key in SETGET_PROPERTIES.keys():
		if ClassDB.is_parent_class(cls_name, key):
			return SETGET_PROPERTIES[key]
	
	return null

static func get_setget_properties(obj: Object) -> Variant:
	return get_setget_properties_of_class(obj.get_class())

static func get_setget_entry(obj: Object, property: String) -> Variant:
	var class_props = get_setget_properties(obj)
	
	var prop_entry: Dictionary
	
	if property in class_props:
		return class_props[property]
	else:
		for prop in class_props.keys():
			if property.begins_with(prop.replace("?", "")):
				return class_props[prop]
				
	return null

static func get_setget_property(obj: Object, property: String) -> Variant:
	var prop_entry = get_setget_entry(obj, property)
	
	if prop_entry == null:
		push_error("Missing setget entry for %s:%s" % [obj.get_class(), property])
		return
	
	if "get" in prop_entry:
		return _call_setget_entry_method(obj, prop_entry, "get", property)

	return obj.get(property)

static func set_setget_property(obj: Object, property: String, value: Variant) -> void:
	var prop_entry = get_setget_entry(obj, property)
	
	if prop_entry == null:
		push_error("Missing setget entry for %s:%s" % [obj.get_class(), property])
		return
	
	if "default" in prop_entry and "reset" in prop_entry:
		var def_val = _call_setget_entry_method(obj, prop_entry, "default", property)
		
		if def_val == value:
			_call_setget_entry_method(obj, prop_entry, "reset", property)
			return
	
	if "set" in prop_entry:
		_call_setget_entry_method(obj, prop_entry, "set", property, [value])
	else:
		obj.set(property, value)

static func _call_setget_entry_method(
	obj: Object, 
	prop_entry: Dictionary, 
	method_name: String, 
	property: String, 
	args: Array = []
) -> Variant:
	var method_entry = prop_entry[method_name]
	
	if method_entry is String:
		return obj.call(method_entry)
		
	var full_args = []
	
	if "args" in method_entry:
		full_args.append_array(method_entry["args"])
	
	for i in args.size():
		if full_args[i] == "?":
			var k = property.split("/")[1]
			full_args[i] = k
	
	full_args.append_array(args)
	
	return obj.callv(method_entry["func"], full_args)

static func is_encoded_resource(value) -> bool:
	return value is Dictionary and "_gdtRes" in value

static func get_ignored_properties(obj: Object) -> Array:
	var res = []
	
	for key in IGNORED_PROPERTIES.keys():
		if obj.is_class(key):
			res.append_array(IGNORED_PROPERTIES[key])
	
	return res

static func is_setget_property(obj: Object, property: String) -> bool:
	var class_props = get_setget_properties(obj)
	
	if not class_props:
		return false
	
	if property in class_props:
		return true
	
	for path: String in class_props.keys():
		if property.begins_with(path.replace("?", "")):
			return true
	
	return false

static func encode_resource(resource: Resource) -> Dictionary:
	var res = {
		"_gdtRes": ResourceType.LOCAL,
		"sub": {}
	}

	var cloned = false

	for key in get_property_keys(resource):
		var value = resource[key]

		if value is Resource:
			if not cloned:
				cloned = true
				resource = resource.duplicate()

			resource[key] = null
			res["sub"][key] = encode_resource(value)

	if not GDTUtils.is_file_resource(resource):
		res["buf"] = var_to_bytes_with_objects(resource)
	else:
		res["_gdtRes"] = ResourceType.FILE
		res["path"] = resource.resource_path

	return res

static func decode_resource(dict: Dictionary) -> Resource:
	assert(is_encoded_resource(dict), "Provided dict isn't a resource dict")

	var resource: Resource

	if "path" in dict:
		assert(GDTValidator.is_path_safe(dict["path"]), "Cannot load resource from unsafe path %s" % dict["path"])

		resource = load(dict["path"])
	elif "buf" in dict:
		resource = bytes_to_var_with_objects(dict["buf"])
		assert(resource is Resource, "Decoded resource isn't a resource")

		if "sub" in dict:
			var sub = dict["sub"]

			if sub is Dictionary:
				for key in sub.keys():
					resource[key] = decode_resource(sub[key])
	else:
		push_error("Cannot decode resource: 'buf' and 'path' missing from resource dict")
	
	return resource

static func get_property_keys(obj: Object) -> Array[String]:
	var res: Array[String] = []
	
	var ignored = get_ignored_properties(obj)
	
	for i in obj.get_property_list():
		var con := true

		if i.name in ignored:
			continue

		for usage in IGNORED_PROPERTY_USAGE_FLAGS:
			if i.usage & usage:
				con = false
				break

		if not con: continue
		res.append(i.name)

	return res

# "node" must be untyped to properly check freed nodes
static func is_node_valid(node) -> bool:
	return (
		node and
		is_instance_valid(node) and
		node.is_inside_tree() and
		(
			(node.owner and is_instance_valid(node.owner))
			or
			node in EditorInterface.get_open_scene_roots()
		)
	)
