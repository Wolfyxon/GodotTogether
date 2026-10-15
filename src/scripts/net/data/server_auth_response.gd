@tool
extends GDTEncodableData
class_name GDTServerAuthResponse

var users: Array = [] # User dicts

var file_config := {
	# path: [size, hash]
}


static func create(main: GodotTogether) -> GDTServerAuthResponse:
	if not main:
		GDTUtils.printerr_stack("main is null")
		return
	
	var res = GDTServerAuthResponse.new()

	res.users = main.server.get_user_dicts()
	res._fill_file_config()
	
	return res

func get_encodable_fields() -> Array:
	return [
		"file_config",
		"users"
	]

func get_file_size(path: String) -> int:
	var entry = get_file_entry(path)
	
	if not entry:
		return -1
	
	return entry[0]

func get_file_entry(path: String) -> Array:
	if not path in file_config:
		return []
		
	var entry = file_config[path]
	
	if typeof(entry) != TYPE_ARRAY:
		GDTUtils.printerr_stack("Invalid file_config. Entry type mismatch")
		return []
	
	if entry.size() != 2:
		GDTUtils.printerr_stack("Invalid file_config. Entry size != 2")
		return []
	
	return entry

func get_total_file_size() -> int:
	var res = 0
	
	for path in file_config:
		var size = get_file_size(path)
		
		if size != -1:
			res += size
		
	return res

func _fill_file_config() -> void:
	file_config.clear()
	
	var fs_tree = GDTFiles.get_file_tree()
	
	for path in fs_tree:
		var file_hash = FileAccess.get_sha256(path)
		var size = FileAccess.get_size(path)
		
		if size == -1:
			GDTUtils.printerr_stack("Failed to get file size: %s" % path)
			continue
		
		file_config[path] = [size, file_hash]

static func from_dict(dict: Dictionary) -> GDTServerAuthResponse:
	var res = GDTServerAuthResponse.new()
	
	if not res.apply_dict(dict):
		return
	
	return res
