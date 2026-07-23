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
	"Node3D": [
		"transform"
	],
	"Resource": [
		"resource_path"
	]
}

var change_timer = Timer.new()
var rescan_timer = Timer.new()

var property_hashes = {
	# [node]: {
	#	[property]: hash,
	#	[object]: {
	#		[property]: hash
	#	}
	#} 
}

var supressed_nodes = {}
var last_scene_path: String = ""

# NOTE: This script is currently NOT used.
# It's an unfinished rewrite of changeDetector

func _ready() -> void:
	change_timer.wait_time = GDTSettings.get_setting("sync/node_refresh_rate")
	change_timer.timeout.connect(_check_changes)
	add_child(change_timer)
	change_timer.start()
	
	ignore_last_changes()

func _check_changes() -> void:
	if not can_sync_nodes(): return
	
	var root := EditorInterface.get_edited_scene_root()
	if not root: return
	
	for node in property_hashes:
		_check_node(node, root)
		
func _check_node(node: Node, root: Node = null) -> void:
	if not is_node_valid(node):
		return
	
	if not root:
		root = EditorInterface.get_edited_scene_root()
	
	if node.owner != root:
		return # Belongs to another scene, ignore.
	
	var last_hashes = property_hashes[node]
	var new_hashes = get_hash_dict(node)
	
	
	
func ignore_last_changes() -> void:
	var root = EditorInterface.get_edited_scene_root()
	
	if not root:
		return
	
	last_scene_path = root.scene_file_path

func observe_node(node: Node) -> void:
	if not is_node_valid(node):
		return
		
	if node in property_hashes:
		return

func set_node_supressed(node: Node, state: bool) -> void:
	if state:
		supressed_nodes.get_or_add(node)
	else:
		supressed_nodes.erase(node)

func observe_node_recursive(node: Node) -> void:
	observe_node(node)
	
	for i in node.get_children():
		observe_node(i)

func observe_current_scene() -> void:
	var scene = EditorInterface.get_edited_scene_root()
	
	if not scene:
		return
		
	observe_node_recursive(scene)

func can_sync_nodes() -> bool:
	return (
		main != null and
		main.is_session_active() and
		not change_timer.paused and
		not (main.client.is_active() and not main.client.is_fully_synced) and
		not GDTSettings.get_setting("dev/disable_node_scanning")
	)

static func get_hash_dict(obj: Object, depth := 64) -> Dictionary:
	var res = {}
	
	for key in get_property_keys(obj):
		var value = obj[key]
		
		if value is Object and depth > 0:
			res[key] = get_hash_dict(value, depth - 1)
		else:
			res[key] = hash(value)
		
	return res

static func is_encoded_resource(value) -> bool:
	return value is Dictionary and "_gdtRes" in value

static func get_ignored_properties(obj: Object) -> Array:
	for key in IGNORED_PROPERTIES.keys():
		if obj.is_class(key):
			return IGNORED_PROPERTIES[key]

	return []

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

static func is_node_valid(node: Node) -> bool:
	return (
		node and
		is_instance_valid(node) and
		node.is_inside_tree() and
		node.owner
	)
