@tool
extends Node
class_name GDTSettings

const DEFAULT_DATA = {
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

	"dev": {
		"disable_real_time_file_sync": false,
		"disable_node_scanning": false
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

static func write_settings(data: Dictionary) -> void:
	var f = FileAccess.open(FILE_PATH, FileAccess.WRITE)

	f.store_string(JSON.stringify(data," "))
	f.close()

static func settings_exist() -> bool:
	return FileAccess.file_exists(FILE_PATH)

static func create_settings() -> void:
	write_settings(DEFAULT_DATA)

static func get_settings_json() -> JSON:
	var file = FileAccess.open(FILE_PATH, FileAccess.READ)
	if not file: return

	var json = JSON.new()

	json.parse(file.get_as_text(), true)
	file.close()

	return json

static func get_settings() -> Dictionary:
	if settings_exist():
		var json = get_settings_json()

		if not json:
			push_error("Unable to access the settings file. Returning default data")
			return GDTUtils.make_editable(DEFAULT_DATA)

		var parsed = json.data
		
		if not parsed:
			push_error("Parsing settings failed at line %s: %s Returning default data." % [json.get_error_line(), json.get_error_message()])
			return GDTUtils.make_editable(DEFAULT_DATA)
		
		parsed = GDTUtils.make_editable(parsed)

		return GDTUtils.merge(parsed, DEFAULT_DATA) 
		
	else:
		return GDTUtils.make_editable(DEFAULT_DATA)

static func get_setting(path: String):
	return GDTUtils.get_nested(get_settings(), path)

static func set_setting(path: String, value) -> void:
	var data = get_settings()

	GDTUtils.set_nested(data, path, value)
	write_settings(data)
