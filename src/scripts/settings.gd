@tool
extends Node
class_name GDTSettings

const _DEFAULT_DATA = {
	"username": "Cool person",
	"format_version": 1,
	
	"last_server": "",
	"last_port": 5017,
	
	"server": {
		"password": "",
		"whitelist": ["127.0.0.1", "0.0.0.0", "0:0:0:0:0:0:0:1"],
		"blacklist": [],
		"whitelist_enabled": false,
		"allow_external_connections": true,
		"require_approval": false
	},
	"sync": {
		"node_refresh_rate": 0.1
	},
	"dev": {
		# Everything here should be false by default
		"disable_real_time_file_sync": false,
		"disable_node_scanning": false,
		"restart_broadcast": false
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
	write_settings(_DEFAULT_DATA)

static func get_default_settings() -> Dictionary:
	return _DEFAULT_DATA.duplicate(true)

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
			return get_default_settings()

		var parsed = json.data
		
		if not parsed:
			push_error("Parsing settings failed at line %s: %s Returning default data." % [json.get_error_line(), json.get_error_message()])
			return get_default_settings()
		
		parsed = parsed.duplicate(true)

		return GDTUtils.merge(parsed, _DEFAULT_DATA) 
		
	else:
		return get_default_settings()

static func get_setting(path: String):
	return GDTUtils.get_nested(get_settings(), path)

static func set_setting(path: String, value) -> void:
	var data = get_settings()

	GDTUtils.set_nested(data, path, value)
	write_settings(data)
