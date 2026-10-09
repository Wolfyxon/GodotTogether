@tool
extends GDTComponent
class_name GDTNodeSync

signal scan_started
signal scan_complete

enum ResourceType {
	LOCAL,
	FILE
}

enum NodeScanMode {
	CONTINUOUS,
	ON_CHANGE
}

enum SetGetBehavior {
	IGNORE,
	SET,
	RESET
}

const DEFAULT_SETGET_NULL_BEHAVIOR = SetGetBehavior.RESET

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
		# Handled by 'transform'
		"position",
		"scale",
		"rotation",
		"rotation_degrees",
		
		"global_position",
		"global_rotation",
		"global_transform",
		"global_scale",
		"global_skew"
	],
	"Node3D": [
		# Handled by 'transform'
		"position",
		"scale",
		"rotation",
		"rotation_degrees",
		
		"global_transform",
		"global_basis",
		"global_scale",
		"global_position",
		"global_rotation",
		"global_rotation_degrees"
	],
	"Resource": [
		#"resource_path"
	]
}

const SETGET_PROPERTIES = {
	"Object": {
		"metadata/?": {
			"reset": {
				"func": "remove_meta",
				"pre_args": ["?"]
			},
			"has": {
				"func": "has_meta",
				"pre_args": ["?"]
			}
		}
	},
	"Control": {
		"theme_override_colors/?": {
			"reset": {
				"func": "remove_theme_color_override",
				"pre_args": ["?"]
			}
		},
		"theme_override_constants/?": {
			"reset": {
				"func": "remove_theme_constant_override",
				"pre_args": ["?"]
			}
		},
		"theme_override_fonts/?": {
			"reset": {
				"func": "remove_theme_font_override",
				"pre_args": ["?"]
			}
		},
		"theme_override_font_sizes/?": {
			"default": "get_theme_default_font_size",
			
			"reset": {
				"func": "remove_theme_font_size_override",
				"pre_args": ["?"]
			}
		},
		"theme_override_icons/?": {
			"reset": {
				"func": "remove_theme_icon_override",
				"pre_args": ["?"]
			}
		},
		"theme_override_styles/?": {
			"reset": {
				"func": "remove_theme_stylebox_override",
				"pre_args": ["?"]
			}
		}
	},
	
	"TileSet": {
		"occlusion_layer_?/light_mask": {
			"reset": {
				"func": "remove_occlusion_layer",
				"post_args": ["?int"]
			}
		},
		"occlusion_layer_?/sdf_collision": {
			"reset": {
				"func": "remove_occlusion_layer",
				"post_args": ["?int"]
			}
		},
		
		"physics_layer_?/collision_layer": {
			"reset": {
				"func": "_tileset_remove_physics_layer",
				"target": GDTNodeSync,
				"post_args": ["?int"]
			}
		},
		"physics_layer_?/collision_priority": {
			"null_behavior": SetGetBehavior.IGNORE
		},
		"physics_layer_?/collision_mask": {
			"null_behavior": SetGetBehavior.IGNORE
		},
		"physics_layer_?/physics_material": {
			"null_behavior": SetGetBehavior.SET,
			
			"has": {
				"func": "_tileset_has_physics_layer",
				"target": GDTNodeSync,
				"post_args": ["?int"]
			},
			"reset": {
				"func": "_tileset_remove_physics_layer",
				"target": GDTNodeSync,
				"post_args": ["?int"]
			},
			"set": {
				"func": "_tileset_set_physics_layer_material",
				"target": GDTNodeSync,
				"pre_args": ["?int"]
			}
		},
		
		"navigation_layer_?/layers": {
			"reset": {
				"func": "remove_navigation_layer",
				"post_args": ["?int"]
			}
		},
		
		"custom_data_layer_?/name": {
			"reset": {
				"func": "remove_custom_data_layer",
				"post_args": ["?int"]
			}
		},
		"custom_data_layer_?/type": {
			"reset": {
				"func": "remove_custom_data_layer",
				"post_args": ["?int"]
			}
		},
		
		"terrain_set_?/mode": {
			"reset": {
				"func": "remove_terrain_set",
				"post_args": ["?int"]
			}
		},
		
		"terrain_set_?/terrain_?/name": {
			"reset": {
				"func": "remove_terrain",
				"post_args": ["?int", "?int"]
			}
		},
		
		"terrain_set_?/terrain_?/color": {
			"reset": {
				"func": "remove_terrain",
				"post_args": ["?int", "?int"]
			}
		},
		
		"sources/?": {
			"get": {
				"func": "get_source",
				"post_args": ["?int"]
			},
			"set": {
				"func": "add_source",
				"post_args": ["?int"]
			},
			"has": {
				"func": "has_source",
				"post_args": ["?int"]
			},
			"reset": {
				"func": "remove_source",
				"post_args": ["?int"]
			}
		}
	},
	
	"TileSetSource": {
		# <coords_x>:<coords_y>/<alternative_id>/<tile_data_property>
		"?:?/?/?": {}
	},
	
	"TileMapLayer": {
		"layer_?/tile_data": {},
		"tile_set:?": {},
	},
	"TileMap": "TileMapLayer",
}

const PROPERTY_SEPARATOR = ":"

var change_timer = Timer.new()
var rescan_timer = Timer.new()

var node_data_dict = {
	# [node]: {
	#	"property_hashes": {
	#		[property]: hash,
	#		[object]: {
	#			".": hash of object instance,
	#			[property]: hash
	#		}
	#	},
	#	"signal_hashes": {
	#		[signal name]: hash of connection list
	#	}
	#	"last_name": name,
	#	"last_path": path
	# } 
}

var supressed_nodes = {}
var last_scene_path: String = ""

var last_input_time: float = 0.0
var last_cycle_time: float = 0.0
var last_scan_time: float = 0.0

var last_change_time: float = 0.0
var recent_change_count: int = 0

func _ready() -> void:
	var editor_ur = EditorInterface.get_editor_undo_redo()
	editor_ur.history_changed.connect(_editor_undo_redo_changed)
	
	update_timer_wait_times()
	main.get_settings().settings_changed.connect(update_timer_wait_times)
	
	change_timer.timeout.connect(_cycle)
	add_child(change_timer)
	change_timer.start()
	
	rescan_timer.wait_time = 1
	rescan_timer.timeout.connect(observe_current_scene)
	add_child(rescan_timer)
	rescan_timer.start()
	
	start()
	report_ready()

func _input(_event: InputEvent) -> void:
	last_input_time = Time.get_unix_time_from_system()

func _cycle() -> void:
	if not main: return
	
	var settings = main.get_settings()
	if not settings: return
	
	var now = Time.get_unix_time_from_system()
	
	last_cycle_time = now
	
	if settings.get_setting("sync/node_scan_pause_unfocused"):
		if not DisplayServer.window_is_focused():
			return
	
	if (now - last_input_time) > 2 and (now - last_scan_time) < 1:
		return
	
	if settings.get_setting("sync/node_scan_mode") != NodeScanMode.CONTINUOUS:
		return
	
	if settings.get_setting("sync/node_adaptive_scan_interval"):
		if(now - last_change_time) > 2 and (now - last_scan_time) < 0.25:
			return
	
	check_changes()

func _got_changes() -> void:
	last_change_time = Time.get_unix_time_from_system()
	recent_change_count += 1

func update_timer_wait_times() -> void:
	change_timer.wait_time = main.get_settings().get_setting("sync/node_refresh_rate")

func check_changes() -> void:
	if not can_sync_nodes(): return
	
	last_scan_time = Time.get_unix_time_from_system()
	
	var root := EditorInterface.get_edited_scene_root()
	if not root: return
	
	if not root.scene_file_path:
		return
	
	if not GDTValidator.is_path_safe(root.scene_file_path):
		return
	
	scan_started.emit()
	
	if main.get_settings().get_setting("dev/log_node_scans"):
		print("Scanning nodes...")
	
	for node in node_data_dict:
		check_node(node, root)
	
	scan_complete.emit()

# "node" must be untyped to prevent freed nodes from stopping the code
func check_node(node, root: Node) -> void:
	if not is_node_valid(node): return
	if not root: return
	
	if not root.is_ancestor_of(node) and node != root:
		return
	
	var data = node_data_dict[node]
	if not data: return
	
	_check_node_properties(node, root, data)
	_check_node_signals(node, root, data)

func _check_node_properties(node, root: Node, data: Dictionary) -> void:
	var last_hashes = data["property_hashes"]
	var new_hashes = get_property_hash_dict(node)
	var diff = get_property_diff(last_hashes, new_hashes)
	
	if "name" in diff:
		_node_renamed(node, data["last_path"])
		data["last_path"] = root.get_path_to(node)
		data["last_name"] = node.name
	
	if not diff.is_empty():
		_node_properties_changed(node, diff)
	
	data["property_hashes"] = new_hashes

func _check_node_signals(node, _root: Node, data: Dictionary) -> void:
	var last_hashes = data["signal_hashes"]
	var new_hashes = get_signal_hash_dict(node)
	
	var diff = GDTUtils.compare_dicts(last_hashes, new_hashes)
	
	if diff.is_empty():
		return
	
	_node_signal_connections_changed(node, diff)
	data["signal_hashes"] = new_hashes

func _editor_undo_redo_changed() -> void:
	if main.settings.get_setting("sync/node_scan_mode") != NodeScanMode.ON_CHANGE:
		return
		
	check_changes()

func _node_signal_connections_changed(node: Node, signal_names: Array) -> void:
	if not can_sync_nodes(): return
	if not is_node_valid(node): return
	
	var dict = get_select_connection_dict(node, signal_names)
	var scene = GDTUtils.get_node_scene(node)
	
	if scene.scene_file_path.is_empty(): return
	if not GDTValidator.is_path_safe(scene.scene_file_path): return
	
	var node_path = scene.get_path_to(node)
	
	await main.file_sync.scan_started
	await main.file_sync.scan_complete
	await get_tree().process_frame
	
	if not scene: 
		return
	
	if main.server.is_active():
		server_broadcast_node_signal_connections_update(node_path, scene.scene_file_path, dict)
	else:
		_c2s_request_signal_connections_update.rpc_id(
			0, 
			node_path, scene.scene_file_path, dict
		)

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
	
	_got_changes()
	
	var scene = GDTUtils.get_node_scene(node)
	if not scene: return
	
	if scene.scene_file_path.is_empty():
		return
	
	if not scene.is_ancestor_of(node) and node != node:
		return
	
	var node_path = scene.get_path_to(node)
	var property_dict = get_select_property_dict(node, property_paths)
	
	if not main.is_session_active():
		return
	
	if is_change_logging_enabled():
		print("Node changed: %s %s" % [node, property_paths])
	
	if main.server.is_active():
		server_broadcast_node_update(node_path, scene.scene_file_path, property_dict)
	else:
		_c2s_request_node_update.rpc_id(1, node_path, scene.scene_file_path, property_dict)

func _node_child_entered_tree(child: Node, parent: Node) -> void:
	# 'owner' is set very late, causing is_node_valid(child) to return false.
	# Do not check it here
	if not is_node_valid(parent): return
	if not can_sync_nodes(): return
	if not is_user_node(child): return
	
	if not is_node_observed(parent): return
	if is_node_observed(child): return
	
	var scene = GDTUtils.get_node_scene(parent)
	if not scene: return
	
	child.owner = scene # Godot isn't fast enough
	var data_dict = observe_node(child)
	
	# Cursed. TODO: Optimize later
	var prop_list = get_property_diff(data_dict["property_hashes"], {})
	var prop_dict = get_select_property_dict(child, prop_list)
	
	var parent_path = scene.get_path_to(parent)
	
	if is_change_logging_enabled():
		print("Node added: %s to %s" % [child, parent])
	
	if main.server.is_active():
		server_broadcast_node_add(parent_path, scene.scene_file_path, child.get_class(), prop_dict)
	else:
		_c2s_request_node_add.rpc_id(1, parent_path, scene.scene_file_path, child.get_class(), prop_dict)

func _node_tree_exiting(node: Node) -> void:
	if not is_node_valid(node): return
	if not can_sync_nodes(): return
	
	var selection = EditorInterface.get_selection()
	selection.remove_node(node)
	
	var scene = EditorInterface.get_edited_scene_root()
	if not scene: return
	
	if node == scene: 
		selection.clear()
		return
	
	if not scene.is_ancestor_of(node): return
	
	var node_path = scene.get_path_to(node)
	
	await get_tree().process_frame
	
	var new_scene = EditorInterface.get_edited_scene_root()
	
	if not node: return
	if not scene: return
	if not new_scene: return
	
	if scene.get_class() != new_scene.get_class():
		return
	
	# Do not delete the node if it was reparented into a node with the same path
	# This is the case for node replacements (class changes).
	# This fixes children of replaced nodes disappearing, while also preserving reparenting.
	# (Actually reparenting creates the node from scratch instead of actually reparenting it lol)
	if node.is_inside_tree() and node_path == scene.get_path_to(node):
		return
	# ---------------------
	
	if is_change_logging_enabled():
		print("Node removed: %s" % node)
	
	if main.server.is_active():
		server_broadcast_node_delete(node_path, scene.scene_file_path)
	else:
		_c2s_request_node_delete.rpc_id(1, node_path, scene.scene_file_path)

func _node_child_order_changed(parent: Node) -> void:
	if not is_node_valid(parent): return
	if is_node_supressed(parent): return
	if not can_sync_nodes(): return
	
	_got_changes()
	
	var scene = GDTUtils.get_node_scene(parent)
	if not scene: return
	
	var parent_path = scene.get_path_to(parent)
	
	var names = []
	var children = parent.get_children()
	
	for i in children.size():
		var child = children[i]
		if not child: continue
		
		if not is_user_node(child):
			continue
		
		names.append(child.name)
	
	if is_change_logging_enabled():
		print("Node children reordered: %s" % parent)
	
	if main.server.is_active():
		server_broadcast_reorder_children(parent_path, scene.scene_file_path, names)
	else:
		_c2s_request_node_reorder.rpc_id(1, parent_path, scene.scene_file_path, names)

func _node_replacing_by(new_node: Node, current_node: Node) -> void:
	#if not is_node_valid(current_node): return
	if not can_sync_nodes(): return
	if is_node_supressed(current_node): return
	
	unobserve_node(current_node)
	
	var scene = EditorInterface.get_edited_scene_root()
	if not scene: return
	
	if scene == new_node:
		_scene_root_replacing(current_node, new_node)
		return
	
	new_node.owner = scene
	new_node.name = current_node.name
	
	if current_node.get_class() == new_node.get_class():
		printerr("Node replacing that isn't a class change not supported")
		return
	
	var path = scene.get_path_to(new_node) # Must get path to new node. Old is already gone
	
	var data_dict = observe_node(new_node)
	var prop_list = get_property_diff(data_dict["property_hashes"], {})
	var prop_dict = get_select_property_dict(new_node, prop_list)
	
	if is_change_logging_enabled():
		print("Node replaced: %s -> %s" % [current_node, new_node])
	
	prop_dict["name"] = current_node.name
	
	if main.server.is_active():
		server_broadcast_node_class_change(
			path, 
			scene.scene_file_path, 
			new_node.get_class(), 
			prop_dict
		)
	else:
		_c2s_request_node_class_change.rpc_id(
			1,
			path, 
			scene.scene_file_path,
			new_node.get_class(),
			prop_dict
		)

func _scene_root_replacing(old_scene: Node, _new_scene: Node) -> void:
	var path = old_scene.scene_file_path
	if not path: return
	
	await get_tree().process_frame
	
	var err = EditorInterface.save_scene()
	
	if err != OK:
		printerr("Not broadcasting scene type change as the save failed")
		return
	
	await main.file_sync.scan_started
	await main.file_sync.scan_complete
	await get_tree().process_frame
	
	if main.server.is_active():
		server_broadcast_scene_reload(path)
	else:
		_c2s_request_scene_reload.rpc_id(1, path)

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
	
	if not GDTValidator.validate_existing_file_path(scene_path):
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
	
	if not GDTValidator.validate_existing_file_path(scene_path):
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
	
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var id = multiplayer.get_remote_sender_id()
	
	server_broadcast_reorder_children(parent_path, scene_path, ordered_names, id)
	reorder_children(parent_path, scene_path, ordered_names)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_node_class_change(
	node_path: String, 
	scene_path: String,
	new_class: String,
	property_dict: Dictionary
) -> void:
	if not main.server.validate_c2s(): 
		return
	
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
		
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
		
	var id = multiplayer.get_remote_sender_id()
	
	server_broadcast_node_class_change(node_path, scene_path, new_class, property_dict, id)
	change_node_class(node_path, scene_path, new_class, property_dict)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_scene_reload(path: String) -> void:
	if not main.server.validate_c2s(): 
		return
	
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
	
	if not GDTValidator.validate_existing_file_path(path):
		return
	
	var id = multiplayer.get_remote_sender_id()
	
	server_broadcast_scene_reload(path, id)
	reload_scene(path)

@rpc("any_peer", "call_remote", "reliable")
func _c2s_request_signal_connections_update(
	node_path: String,
	scene_path: String, 
	dict: Dictionary
) -> void:
	if not main.server.validate_c2s(): 
		return
		
	if not main.server.caller_has_permission(GodotTogether.Permission.EDIT_SCENES):
		return
	
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	if not dict:
		return
	
	var id = multiplayer.get_remote_sender_id()
	update_node_signal_connections(node_path, scene_path, dict)
	server_broadcast_node_signal_connections_update(node_path, scene_path, dict, id)

@rpc("authority", "call_remote", "reliable")
func update_node_properties(node_path: String, scene_path: String, property_dict: Dictionary) -> void:
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var node = GDTUtils.get_node_in_scene(node_path, scene_path)
	if not node: return
	
	if is_remote_change_logging_enabled():
		print("Got node update for: '%s' in scene: '%s'" % [node_path, scene_path])
		print(property_dict)
	
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
	
	if is_remote_change_logging_enabled():
		print("Got node rename '%s' in scene '%s'" % [node_path, scene_path])
		print("New name: %s" % new_name)
	
	set_node_supressed(node, true)
	
	if node in node_data_dict:
		node_data_dict[node]["property_hashes"]["name"] = hash(new_name)
	
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
	
	var scene = GDTUtils.get_loaded_scene_root(scene_path)
	if not scene: return
	
	var parent = scene.get_node_or_null(parent_path)
	
	if not parent: 
		printerr("Parent not found %s in scene %s" % [parent_path, scene_path])
		return
	
	if not "name" in property_dict:
		printerr("Missing 'name' in property dict")
		return
	
	if parent.has_node(NodePath(property_dict["name"])):
		return
	
	if is_remote_change_logging_enabled():
		print("Got new node in parent '%s' scene '%s'" % [parent_path, scene_path])
		print(property_dict)
	
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
	
	var scene = GDTUtils.get_loaded_scene_root(scene_path)
	if not scene: return
	
	var node = scene.get_node_or_null(node_path)
	if not node: return
	
	if node == scene:
		printerr("Deleting scene root not supported")
		return
	
	if is_remote_change_logging_enabled():
		print("Got node delete '%s' in '%s'" % [node_path, scene_path])
	
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
		var path = NodePath(ordered_names[i])
		var child = parent.get_node_or_null(path)
		
		if not child: 
			#printerr("Failed to get node in %s for reorder: %s" % [parent, path])
			continue
		
		parent.move_child(child, i)
		
	set_node_supressed(parent, false)

@rpc("authority", "call_remote", "reliable")
func change_node_class(
	node_path: String, 
	scene_path: String,
	new_class: String,
	property_dict: Dictionary
) -> void:
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var scene = GDTUtils.get_loaded_scene_root(scene_path)
	if not scene: return
	
	var old_node = scene.get_node_or_null(node_path)
	if not old_node: return
	
	if old_node in EditorInterface.get_open_scene_roots():
		# Godot does not properly recognize the new scene root, even
		# after changing SceneTree.edited_scene_root.
		# A file-based workaround is used in _scene_root_replacing()
		printerr("Attempt to replace root of an open scene.")
		return
	
	if old_node.get_class() == new_class:
		return
	
	var new_node = validate_and_create_node(new_class)
	if not new_node: return
	
	apply_property_dict(new_node, property_dict)
	
	if not is_user_node(new_node):
		printerr("Replacing node failed, name was not applied")
		return
	
	if is_remote_change_logging_enabled():
		print("Got node class change %s in %s" % [node_path, scene_path])
		print("New class: %s" % new_class)
	
	set_node_supressed(old_node, true)
	
	old_node.replace_by(new_node)
	
	unobserve_node(old_node)
	
	await get_tree().process_frame
	
	if old_node and not old_node.is_inside_tree():
		old_node.queue_free()

@rpc("authority", "reliable")
func update_node_signal_connections(
	node_path: String,
	scene_path: String, 
	dict: Dictionary
) -> void:
	await get_tree().process_frame
	
	if not GDTValidator.validate_existing_file_path(scene_path):
		return
	
	var node = GDTUtils.get_node_in_scene(node_path, scene_path)
	if not node: return
	
	apply_signal_connection_dict(node, dict)
	
	if node in node_data_dict:
		node_data_dict[node]["signal_hashes"] = get_signal_hash_dict(node)

@rpc("authority", "reliable")
func reload_scene(path: String) -> void:
	# EditorInterface.reload_scene() is not reliable
	
	if not GDTValidator.is_path_safe(path):
		printerr("Server tried to reload scene at unsafe location: %s" % path)
		return
	
	if not FileAccess.file_exists(path):
		printerr("Attempt to reload nonexistent scene: %s" % path)
		return
	
	var scene_paths = EditorInterface.get_open_scenes()
	var current_scene_path = ""
	var scene = EditorInterface.get_edited_scene_root()
	
	if not path in scene_paths:
		return
	
	if scene and scene.scene_file_path:
		current_scene_path = scene.scene_file_path
	
	EditorInterface.get_selection().clear()
	
	for i in scene_paths:
		if not i: continue
		
		EditorInterface.open_scene_from_path(i)
		
		if i != path:
			EditorInterface.save_scene()
		
		EditorInterface.close_scene()
	
	for i in scene_paths:
		EditorInterface.open_scene_from_path(i)
	
	if current_scene_path:
		EditorInterface.open_scene_from_path(current_scene_path)

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

func server_broadcast_node_class_change(
	node_path: String, 
	scene_path: String,
	new_class: String,
	property_dict: Dictionary,
	sender := 0
) -> void:
	main.server.auth_rpc(change_node_class, [node_path, scene_path, new_class, property_dict], [sender])

func server_broadcast_scene_reload(path: String, sender := 0) -> void:
	main.server.auth_rpc(reload_scene, [path], [sender])

func server_broadcast_node_signal_connections_update(
	node_path: String,
	scene_path: String,
	dict: Dictionary,
	sender := 0
) -> void:
	main.server.auth_rpc(update_node_signal_connections, [node_path, scene_path, dict], [sender])

func validate_and_create_node(node_class: String) -> Node:
	if not ClassDB.class_exists(node_class):
		GDTUtils.printerr_stack("Class '%s' doesn't exist" % node_class)
		return
	
	var node = ClassDB.instantiate(node_class)
	
	if not node:
		GDTUtils.printerr_stack("Unable to create clas '%s'" % node_class)
		return
	
	if not node is Node:
		GDTUtils.printerr_stack("Class '%s' is not a Node" % node_class)
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
	
	if not scene.is_ancestor_of(node) and node != scene:
		GDTUtils.printerr_stack("Cannot get data of %s: scene mismatch" % node)
		return {}
	
	return {
		"name": node.name,
		"last_path": scene.get_path_to(node),
		"property_hashes": get_property_hash_dict(node),
		"signal_hashes": get_signal_hash_dict(node)
	}

func unobserve_node(node: Node) -> void:
	node_data_dict.erase(node)
	supressed_nodes.erase(node)

func observe_node(node: Node) -> Dictionary:
	if not is_node_valid(node):
		return {}
	
	if node in node_data_dict:
		return node_data_dict[node]
	
	GDTUtils.try_connect_bulk({
		node.child_entered_tree: _node_child_entered_tree.bind(node),
		node.child_order_changed: _node_child_order_changed.bind(node),
		node.tree_exiting: _node_tree_exiting.bind(node),
		node.replacing_by: _node_replacing_by.bind(node)
	})
	
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
	if not scene: return
	if not scene.scene_file_path: return
	
	if not GDTValidator.is_path_safe(scene.scene_file_path):
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
		(
			main.is_session_active() or
			main.get_settings().get_setting("dev/always_scan_nodes")
		) and
		not change_timer.paused and
		not (main.client.is_active() and not main.client.is_fully_synced) and
		not main.get_settings().get_setting("dev/disable_real_time_node_sync")
	)

func is_change_logging_enabled() -> bool:
	return (
		main and main.get_settings() and
		main.get_settings().get_setting("dev/log_node_changes")
	)

func is_remote_change_logging_enabled() -> bool:
	return (
		main and main.get_settings() and
		main.get_settings().get_setting("dev/log_node_remote_changes")
	)

static func get_signal_hash_dict(node: Node) -> Dictionary:
	var res = {}
	var signals = node.get_signal_list()
	
	for sig in signals:
		var sig_name = sig["name"]
		var connections = get_user_signal_connections(node, sig_name)
		
		res[sig_name] = hash(connections)
	
	return res

static func encode_callable_ref(callable: Callable) -> Dictionary:
	var method_name = callable.get_method()
	
	if not method_name:
		GDTUtils.printerr_stack("Method name is empty")
		return {}
	
	if method_name.contains("<"):
		GDTUtils.printerr_stack("Cannot encode annonymous lambdas")
		return {}
	
	return {
		"name": method_name,
		"bind_args": callable.get_bound_arguments()
	}

static func decode_callable_ref(node: Node, dict: Dictionary) -> Callable:
	if not node:
		GDTUtils.printerr_stack("Node null or freed")
		return _invalid_callable
	
	if not is_encoded_calllable_ref(dict):
		GDTUtils.printerr_stack("Invalid callable dict: %s" % dict)
		return _invalid_callable
	
	var method_name = dict["name"]
	
	var cal = Callable(node, method_name)
	
	# You can't access properties of scripts that aren't in tool mode
	#if not cal:
		#GDTUtils.printerr_stack("%s has no method %s" % [node, method_name])
		#return _invalid_callable
	
	#if typeof(cal) != TYPE_CALLABLE:
		#GDTUtils.printerr_stack("%s: %s is not a method: %s" % [node, method_name, cal])
		#return _invalid_callable
	
	if dict["bind_args"]:
		return cal.bindv(dict["bind_args"])
	
	return cal

static func get_select_connection_dict(node: Node, signal_names: Array) -> Dictionary:
	var res = {}
	
	for sig_name in signal_names:
		var callable_dicts = []
		var connections = get_user_signal_connections(node, sig_name)
		
		for con in connections:
			var cal = con["callable"]
			callable_dicts.append(encode_callable_ref(cal))
		
		res[sig_name] = callable_dicts
		
	return res

static func is_encoded_calllable_ref(dict: Dictionary) -> bool:
	return (
		typeof(dict) == TYPE_DICTIONARY and
		
		"name" in dict and
		(typeof(dict["name"]) == TYPE_STRING or typeof(dict["name"]) == TYPE_STRING_NAME) and
		
		"bind_args" in dict and 
		typeof(dict["bind_args"]) == TYPE_ARRAY
	)

static func get_user_signal_connections(node: Node, signal_name: String) -> Array:
	var res = []
	var connections = node.get_signal_connection_list(signal_name)
	
	for con in connections:
		if con["flags"] & ConnectFlags.CONNECT_PERSIST:
			res.append(con)
	
	return res

static func clear_user_signal_connections(node: Node, signal_name: String) -> void:
	var connections = node.get_signal_connection_list(signal_name)
	
	for con in connections:
		if con["flags"] & ConnectFlags.CONNECT_PERSIST:
			var sig: Signal = con["signal"]
			sig.disconnect(con["callable"])

static func apply_signal_connection_dict(node: Node, dict: Dictionary) -> void:
	for sig_name in dict.keys():
		if not node.has_signal(sig_name):
			continue
		
		clear_user_signal_connections(node, sig_name)
		
		for cal_dict in dict[sig_name]:
			var cal = decode_callable_ref(node, cal_dict)
			
			if cal == _invalid_callable:
				continue
			
			node.connect(sig_name, cal, ConnectFlags.CONNECT_PERSIST)

static func get_property_diff(hash_dict_a: Dictionary, hash_dict_b: Dictionary) -> Array:
	return GDTUtils.compare_dicts(hash_dict_a, hash_dict_b, PROPERTY_SEPARATOR)

static func get_property_hash_dict(obj: Object, depth := 64) -> Dictionary:
	var res = {}
	fill_property_hash_dict(res, obj, depth)
	return res

static func fill_property_hash_dict(res: Dictionary, obj: Object, depth := 64) -> Dictionary:
	for key in get_property_keys(obj):
		if not key in obj:
			continue
		
		var value = obj[key]
		
		if value is Object and depth > 0:
			res[key] = {
				"." = hash(value)
			}
			fill_property_hash_dict(res[key], value, depth - 1)
		else:
			res[key] = hash(value)
		
	return res

static func get_select_property_dict(obj: Object, paths: Array) -> Dictionary:
	var res = {}
	
	for path: String in paths:
		var true_path = path.replace(PROPERTY_SEPARATOR + ".", "")
		var is_setget = is_setget_property(obj, path)
		
		var value = null
		
		if is_setget:
			value = get_setget_property(obj, path)
		else:
			value = obj.get_indexed(true_path)#GDTUtils.get_nested(obj, true_path, PROPERTY_SEPARATOR)
		
		if value is Resource:
			value = encode_resource(value)
		
		#if value == null and path.contains("/") and not is_setget:
			#if path.contains("/") and not path.ends_with("."):
				#GDTUtils.printerr_stack("Setget property not implemented: %s: %s" % [obj.get_class(), path])
		
		res[true_path] = value
	
	return res

static func should_property_be_ignored(obj: Object, path: String) -> bool:
	# Fixes "Cannot set material emission intensity when Physical Light Units disabled."
	if obj is BaseMaterial3D:
		if (
			not obj.emission_enabled and
			path.begins_with("emission_") and 
			path != "emission_enabled"
		):
			return true
	
	return false

static func apply_property_dict(obj: Object, dict: Dictionary) -> void:
	for path in dict.keys():
		var value = dict[path]
		
		if should_property_be_ignored(obj, path):
			continue
		
		if is_encoded_resource(value):
			value = decode_resource(value)
		
		if is_setget_property(obj, path):
			set_setget_property(obj, path, value)
		else:
			var original = obj.get_indexed(path)
			obj.set_indexed(path, value)
			var new_value = obj.get_indexed(path)
			
			if value != original and new_value != value:
				GDTUtils.printerr_stack(
					"Set failed: %s Attempted: %s Got: %s" % 
					[path, str(value), str(new_value)]
				)

static func get_setget_properties_of_class(cls_name: String) -> Variant:
	var res = {}
	var found = false
	
	if cls_name in SETGET_PROPERTIES:
		var value = SETGET_PROPERTIES[cls_name]
		
		if value is String:
			if value in SETGET_PROPERTIES:
				value = SETGET_PROPERTIES[value]
				
		return value
	
	for cls_key in SETGET_PROPERTIES.keys():
		if cls_name != cls_key and not ClassDB.is_parent_class(cls_name, cls_key):
			continue
		
		var value = SETGET_PROPERTIES[cls_key]
		
		if value is String:
			if not value in SETGET_PROPERTIES:
				continue
			
			value = SETGET_PROPERTIES[value]
		
		res = GDTUtils.merge(res, value.duplicate(true))
		found = true
	
	if found:
		return res
	
	return null

static func get_setget_properties(obj: Object) -> Variant:
	return get_setget_properties_of_class(obj.get_class())

static func get_setget_entry_name(class_props: Dictionary, property: String) -> String:
	if not class_props:
		GDTUtils.printerr_stack("Got empty prop dict")
		return ""
	
	if not property:
		GDTUtils.printerr_stack("Property path empty.")
		return ""
	
	if property in class_props:
		return property
	else:
		for path in class_props.keys():
			var regex = get_property_match_regex(path)
			
			if regex.search(property):
				return path
	
	return ""

static func get_setget_property(obj: Object, property: String) -> Variant:
	if not property:
		GDTUtils.printerr_stack("Trying to get empty property of %s" % obj.get_class())
		return
	
	var first = property.split(":")[0]
	var new_path = property.substr(first.length() + 1)
	
	if new_path and first in obj and obj[first] is Object:
		if is_setget_property(obj[first], new_path):
			return get_setget_property(obj[first], new_path)
		else:
			return obj[first].get_indexed(new_path)
	
	var props = get_setget_properties(obj)
	
	if not props:
		GDTUtils.printerr_stack(
			"No setget properties for class '%s'. Tried getting: '%s'" % 
			[obj.get_class(), property]
		)
		return
	
	var prop_entry_name = get_setget_entry_name(props, property)
	
	if not prop_entry_name:
		GDTUtils.printerr_stack(
			"No setget property entry for %s '%s'. Attempted get" % 
			[obj.get_class(), property]
		)
		return
	
	var prop_entry = props[prop_entry_name]
	
	if prop_entry == null:
		GDTUtils.printerr_stack("Missing setget entry for %s: %s" % [obj.get_class(), property])
		return
	
	if "has" in prop_entry:
		if not _call_setget_entry_method(obj, prop_entry, prop_entry_name, "has", property):
			return
	
	if "get" in prop_entry:
		return _call_setget_entry_method(obj, prop_entry, prop_entry_name, "get", property)

	return obj.get(property)

static func set_setget_property(obj: Object, property: String, value: Variant) -> void:
	if not property:
		GDTUtils.printerr_stack("Trying to set empty property of %s" % obj.get_class())
		return
	
	var first = property.split(":")[0]
	var new_path = property.substr(first.length() + 1)
	
	if new_path and first in obj and obj[first] is Object:
		if is_setget_property(obj[first], new_path):
			set_setget_property(obj[first], new_path, value)
		else:
			obj[first].set_indexed(new_path, value)
		
		return
	
	var props = get_setget_properties(obj)
	
	if not props:
		GDTUtils.printerr_stack(
			"No setget properties for class '%s'. Tried setting: '%s'" % 
			[obj.get_class(), property]
		)
		return
	
	var prop_entry_name = get_setget_entry_name(props, property)
	
	if not prop_entry_name:
		GDTUtils.printerr_stack(
			"No setget property entry for %s '%s'. Attempted set" % 
			[obj.get_class(), property]
		)
		return
	
	var prop_entry = props[prop_entry_name]
	
	if prop_entry == null:
		GDTUtils.printerr_stack("Missing setget entry for %s:%s" % [obj.get_class(), property])
		return
		
	var null_bhv = DEFAULT_SETGET_NULL_BEHAVIOR
		
	if "null_behavior" in prop_entry:
		null_bhv = prop_entry["null_behavior"]
		
	if value == null and null_bhv == SetGetBehavior.IGNORE:
		return

	if "reset" in prop_entry:
		if "default" in property:
			var def_val = _call_setget_entry_method(obj, prop_entry, prop_entry_name, "default", property)
			
			if def_val == value:
				_call_setget_entry_method(obj, prop_entry, prop_entry_name, "reset", property)
				
				return
			
		elif "has" in property:
			if not _call_setget_entry_method(obj, prop_entry, prop_entry_name, "has", property):
				_call_setget_entry_method(obj, prop_entry, prop_entry_name, "reset", property)
		
		if value == null and null_bhv == SetGetBehavior.RESET:
			_call_setget_entry_method(obj, prop_entry, prop_entry_name, "reset", property)
			return
	
	if "set" in prop_entry:
		_call_setget_entry_method(obj, prop_entry, prop_entry_name, "set", property, [value])
	else:
		obj.set(property, value)
		
	var new_val = get_setget_property(obj, property)
	
	if new_val != value:
		GDTUtils.printerr_stack("Setting setget property failed: %s '%s'" % [obj.get_class(), property])

static func get_setget_func_args_fragment(
	source_args: Array,
	prop_entry_name: String,
	property: String,
	pos := 0
) -> Array:
	if not property:
		GDTUtils.printerr_stack("Got empty property")
		return []
		
	if not prop_entry_name:
		GDTUtils.printerr_stack("Got empty property entry name")
		return []
	
	var extracted = extract_setget_property_string_args(property, prop_entry_name).slice(pos)
	
	var res = []
	
	for i in min(extracted.size(), source_args.size()):
		var ex: String = extracted[i]
		var src: String = source_args[i]
		
		if src == "?":
			res.append(ex)
		if src == "?int":
			if ex.is_valid_int():
				res.append(int(ex))
			else:
				GDTUtils.printerr_stack("Invalid int '%s'. Property: %s" % [ex, property])
	
	return res
	
static func get_setget_func_args(
	method_entry: Dictionary,
	prop_entry_name: String,
	property: String, 
	input_args: Array = []
) -> Array:
	var full_args = []
	var templ_args_pos = 0
	
	if "pre_args" in method_entry:
		var arr = get_setget_func_args_fragment(method_entry["pre_args"], prop_entry_name, property)
		full_args.append_array(arr)
		templ_args_pos = arr.size()
	
	full_args.append_array(input_args)
	
	if "post_args" in method_entry:
		var arr = get_setget_func_args_fragment(method_entry["post_args"], prop_entry_name, property, templ_args_pos)
		full_args.append_array(arr)
		
	return full_args

static func _call_setget_entry_method(
	obj: Object, 
	prop_entry: Dictionary,
	prop_entry_name: String,
	method_name: String, 
	property: String, 
	args: Array = []
) -> Variant:
	var method_entry = prop_entry[method_name]
	
	if method_entry is String:
		return obj.call(method_entry)
	
	var full_args = get_setget_func_args(method_entry, prop_entry_name, property, args)
	
	var func_value = method_entry["func"]
	var func_target = obj
	
	if "target" in method_entry:
		var target_val = method_entry["target"]
		
		full_args.push_front(obj)
		
		if target_val is Object:
			func_target = target_val
	
	return func_target[func_value].callv(full_args)

static func is_encoded_resource(value) -> bool:
	if not value is Dictionary:
		return false
		
	if not "_gdtRes" in value:
		return false
	
	if not "hash" in value:
		return false
	
	if typeof(value["_gdtRes"]) != TYPE_INT:
		return false
	
	if typeof(value["hash"]) != TYPE_INT:
		return false
	
	return true

static func get_encoded_resource_hash(dict: Dictionary) -> int:
	var current = 0
	
	for key in dict.keys():
		if key == "hash":
			continue
		
		var val = dict[key]
		
		if is_encoded_resource(val):
			var sub_hash = hash(get_encoded_resource_hash(val))
			current += sub_hash
	
	return current

# Users may create dictionaries that the plugin will interpret as resources and break.
# This makes it impossible without automation.
static func validate_encoded_resource_integrity(dict: Dictionary) -> bool:
	var claimed_hash = dict["hash"]
	var real_hash = get_encoded_resource_hash(dict)
	
	return claimed_hash == real_hash

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
		var regex := get_property_match_regex(path)
		
		if regex.search(property):
			return true
		
	return false

static func get_property_match_regex(path: String) -> RegEx:
	var regex = RegEx.new()
	
	var err = regex.compile(
		path.replace("?", "(.*)")
			.replace("/", "\\/")
			.replace(":", "\\:")
		)
	
	if err != OK:
		GDTUtils.printerr_stack("Invalid regex: %s" % path)
		return
	
	return regex

static func extract_setget_property_string_args(property: String, source: String) -> Array:
	var regex = get_property_match_regex(source)
	var res = regex.search(property)
	
	if not res:
		return []
		
	return res.strings.slice(1)

static func encode_resource(resource: Resource) -> Dictionary:
	var res = {
		"_gdtRes": ResourceType.LOCAL,
		"props": {}
	}
	
	var is_file = GDTUtils.is_file_resource(resource)
	
	if is_file:
		res["_gdtRes"] = ResourceType.FILE
		res["path"] = resource.resource_path
	else:
		res["class"] = resource.get_class()
		
		for key in get_property_keys(resource):
			var value
			
			if is_setget_property(resource, key):
				value = get_setget_property(resource, key)
			elif key in resource:
				value = resource[key]
			
			res["props"][key] = value
	
	res["hash"] = get_encoded_resource_hash(res)
	
	return res

static func decode_resource(dict: Dictionary, allow_unsafe := false) -> Resource:
	if not is_encoded_resource(dict):
		GDTUtils.printerr_stack("Provided dict isn't a valid resource dict")
		return
	
	if not validate_encoded_resource_integrity(dict):
		GDTUtils.printerr_stack("Encoded resource does not pass integrity check.")
		return
	
	var tp = dict["_gdtRes"]
	
	match tp:
		ResourceType.LOCAL:
			return _decode_local_resource(dict)
		ResourceType.FILE:
			return _decode_file_resource(dict, allow_unsafe)
	
	GDTUtils.printerr_stack("Unknown encoded resource type: %s" % tp)
	return

static func _decode_local_resource(dict: Dictionary) -> Resource:
	if not "class" in dict:
		GDTUtils.printerr_stack("Cannot decode resource. 'class' missing")
		return
	
	if not "props" in dict:
		GDTUtils.printerr_stack("Cannot decode resource. 'props' missing")
		return
	
	var cls = dict["class"]
	var props = dict["props"]
	
	if not ClassDB.class_exists(cls):
		GDTUtils.printerr_stack("Cannot decode resource of unknown class: %s" % cls)
		return
	
	if not ClassDB.is_parent_class(cls, "Resource"):
		GDTUtils.printerr_stack("Cannot decode resource. Class '%s' is not a Resource" % cls)
		return
	
	var res = ClassDB.instantiate(cls)
	
	if not res:
		GDTUtils.printerr_stack("Failed to create resource")
		return
	
	apply_property_dict(res, props)
	return res

static func _decode_file_resource(dict: Dictionary, allow_unsafe := false) -> Resource:
	if not "path" in dict:
		GDTUtils.printerr_stack("Cannot load resource. 'path' missing.")
		return
	
	var path = dict["path"]
	
	if not allow_unsafe and not GDTValidator.is_path_safe(path):
		GDTUtils.printerr_stack("Cannot load resource from unsafe path: %s" % path)
		return
	
	var loaded = load(path)
	
	if not loaded:
		GDTUtils.printerr_stack("Failed to load: %s" % path)
		return
		
	if not loaded is Resource:
		GDTUtils.printerr_stack("Not a resource: %s" % path)
		return
	
	return loaded

static func get_property_keys(obj: Object) -> Array[String]:
	var res: Array[String] = []
	
	var ignored = get_ignored_properties(obj)
	var ignored_regex = []
	
	for i in ignored:
		var regex = get_property_match_regex(i)
		
		if regex:
			ignored_regex.append(regex)
	
	for i in obj.get_property_list():
		var ok := true
		
		for regex: RegEx in ignored_regex:
			if regex.search(i["name"]):
				ok = false
				break

		for usage in IGNORED_PROPERTY_USAGE_FLAGS:
			if i["usage"] & usage:
				ok = false
				break

		if not ok: continue
		res.append(i.name)

	return res

static func is_user_node(node: Node) -> bool:
	return node and is_instance_valid(node) and not node.name.contains("@")

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

static func _tileset_has_physics_layer(tileset: TileSet, id: int) -> bool:
	return tileset and tileset.get_physics_layers_count() > id

static func _tileset_remove_physics_layer(tileset: TileSet, id: int) -> void:
	if _tileset_has_physics_layer(tileset, id):
		tileset.remove_physics_layer(id)

static func _tileset_set_physics_layer_material(tileset: TileSet, id: int, material: PhysicsMaterial) -> void:
	if _tileset_has_physics_layer(tileset, id):
		tileset.set_physics_layer_physics_material(id, material)

static func _invalid_callable() -> void:
	GDTUtils.printerr_stack("Placeholder invalid callable called!")
