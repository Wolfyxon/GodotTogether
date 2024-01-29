extends Node
class_name GodotTogetherSettings

const default_data = {
	"username": "Cool person",
	"format_version": 1
}

const file_path = "res://addons/GodotTogether/settings.json"

static func write_settings(data: Dictionary):
	var f = FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()

static func settings_exist() -> bool:
	return FileAccess.file_exists(file_path)

static func get_settings() -> Dictionary:
	if settings_exist():
		var f = FileAccess.open(file_path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		
		if not parsed:
			push_error("Parsing settings failed, returning default data")
			return default_data
		
		return parsed
		
	else:
		return default_data

static func create_settings():
	write_settings(default_data)
