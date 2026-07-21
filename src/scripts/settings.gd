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
		"port": 5017,
		"max_users": 10,
		"whitelist": ["127.0.0.1", "0.0.0.0", "0:0:0:0:0:0:0:1"],
		"blacklist": [],
		"whitelist_enabled": false,
		"allow_external_connections": true,
		"require_approval": false
	},
	"sync": {
		"node_refresh_rate": 0.1
	},
	"update": {
		"latest_version": null,
		"download_url": null,
		"last_check": 0,
		"check_interval_hours": 720, # monthly
		"auto_check_enabled": true
	},
	"dev": {
		# Everything here should be false by default
		"run_tests_on_start": false,
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

	f.store_string(JSON.stringify(data,"	"))
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

static func _set_setting_reverse(value, path: String) -> void:
	prints(value, path)
	set_setting(path, value)

static func make_setting_control(node: Control, path: String) -> void:
	if node is OptionButton:
		node.item_selected.connect(func(idx):
			var id = node.get_item_id(idx)
			set_setting(path, id)
		)
	elif node is Button:
		if not node.toggle_mode:
			push_error("Button %s must have toggle_mode enabled" % node.name)
		
		node.toggled.connect(_set_setting_reverse.bind(path))
	elif node is SpinBox:
		node.value_changed.connect(_set_setting_reverse.bind(path))
	elif node is LineEdit:
		node.text_changed.connect(_set_setting_reverse.bind(path))
	
	update_control(node, path)

static func update_control(node: Control, path: String) -> void:
	var value = get_setting(path)
	
	GDTUtils.set_control_value(node, value)
