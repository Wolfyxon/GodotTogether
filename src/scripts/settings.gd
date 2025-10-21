@tool
extends Node
class_name GDTSettings

const default_data = {
	"username": "Cool person",
	"format_version": 1,
	
	"last_server": "",
	"last_port": 5017,
	
	"server": {
		"password": "",
		"whitelist": ["127.0.0.1", "0.0.0.0", "0:0:0:0:0:0:0:1"], # IP address whitelist
		"blacklist": [], # blocked IP addresses
		"whitelist_enabled": false,
		"allow_external_connections": true, # allow connections outside of the local network (if the user has open ports) 
		"require_approval": false
	},

	"advanced": {
		"real_time_file_sync": true,
		"node_scanning": true
	},

	"notifications": {
		"users": true
	},
	
	"seen" : {
		"disclaimer": false
	}
}

const FILE_PATH = "res://addons/GodotTogether/settings.json"

static func get_absolute_path() -> String:
	return ProjectSettings.globalize_path(FILE_PATH)

static func make_editable(dict: Dictionary) -> Dictionary:
	if not dict.is_read_only(): 
		return dict
	
	return dict.duplicate(true)

static func write_settings(data: Dictionary) -> void:
	var f = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data," "))
	f.close()

static func settings_exist() -> bool:
	return FileAccess.file_exists(FILE_PATH)

static func create_settings() -> void:
	write_settings(default_data)

static func get_settings_json() -> JSON:
	var file = FileAccess.open(FILE_PATH, FileAccess.READ)
	if not file: return

	var json = JSON.new()

	json.parse(file.get_as_text(), true)
	file.close()

	return json

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	for key in b.keys():
		if not key in a:
			a[key] = b[key]

		if (a[key] is Dictionary) and (b[key] is Dictionary):
			a[key] = merge(a[key], b[key])

	return a

static func get_settings() -> Dictionary:
	if settings_exist():
		var json = get_settings_json()

		if not json:
			push_error("Unable to access the settings file. Returning default data")
			return make_editable(default_data)

		var parsed = json.data
		
		if not parsed:
			push_error("Parsing settings failed at line %s: %s Returning default data." % [json.get_error_line(), json.get_error_message()])
			return make_editable(default_data)
		
		parsed = make_editable(parsed)

		return merge(parsed, default_data) 
		
	else:
		return make_editable(default_data)

static func get_nested(dict: Dictionary, path:String, separator := "/"):
	var levels = path.split(separator)
	var current = dict
	
	for level in levels:
		if not current.has(level): return
		current = current[level]
	
	return current

static func set_nested(dict: Dictionary, path: String, value, separator:= "/") -> void:
	assert(not dict.is_read_only(), "Dictionary is read only")
	
	var levels = path.split(separator)
	var current = dict

	for i in range(levels.size() - 1):
		var level = levels[i]
		if not current.has(level):
			current[level] = {}
		
		current = current[level]

	current[levels[-1]] = value

static func get_setting(path: String):
	return get_nested(get_settings(), path)

static func set_setting(path: String, value) -> void:
	var data = get_settings()
	set_nested(data, path, value)
	write_settings(data)
