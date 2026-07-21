@tool
extends Node
class_name GDTUpdateInstaller

# IMPORTANT: Do not use any GodotTogether classes here. 
# This script must be independent

const PLUGIN_DIR = "res://addons/GodotTogether"
const SETTINGS_FILE = "settings.json"

var zip_path: String = ""
var zip: ZIPReader

var settings_buf = []

func _ready() -> void:
	await get_tree().process_frame # Wait for shutdown
	
	save_settings()
	
	print("[GodotTogether] Removing current plugin version")
	remove_dir_recursive(PLUGIN_DIR)
	
	unzip()
	restore_settings()
	finish()

func unzip() -> void:
	print("[GodotTogether] Writing files")
	
	for file_path in zip.get_files():
		var buf = zip.read_file(file_path)
		var physical_path = PLUGIN_DIR + "/" + file_path
				
		ensure_dir_exists(physical_path)
		
		var file = FileAccess.open(physical_path, FileAccess.WRITE)
		
		if not file:
			printerr("Unable to create file %s" % physical_path)
			continue
		
		file.store_buffer(buf)
		
		print(file_path)
		
	print("[GodotTogether] Update files extracted")

func save_settings() -> void:
	var settings_path = PLUGIN_DIR + "/" + SETTINGS_FILE
	
	if FileAccess.file_exists(settings_path):
		print("[GodotTogether] Backing up settings")
		
		settings_buf = FileAccess.get_file_as_bytes(settings_path)
		
func restore_settings() -> void:
	var settings_path = PLUGIN_DIR + "/" + SETTINGS_FILE
	
	if not settings_buf.is_empty():
		print("[GodotTogether] Restoring settings")
		
		var file = FileAccess.open(settings_path, FileAccess.WRITE)
		
		if not file:
			printerr("Unable to restore settings file")
			return
			
		if not file.store_buffer(settings_buf):
			printerr("Unable to write settings")

func validate() -> String:
	var files = zip.get_files()
	
	if files.is_empty():
		return "Archive is empty"
	
	if not "plugin.cfg" in files:
		return "Missing plugin manifest"
	
	return ""

func open_zip(path: String) -> int:
	zip = ZIPReader.new()
	zip_path = path
	return zip.open(path)

func start() -> void:
	var root = EditorInterface.get_base_control()
	root.add_child(self)

func finish() -> void:
	print("[GodotTogether] Update complete. Restarting plugin")
	
	zip.close()
	EditorInterface.get_resource_filesystem().scan()
	
	for i in range(5):
		await get_tree().process_frame
	
	EditorInterface.set_plugin_enabled("GodotTogether", true)
	
	await get_tree().process_frame
	
	print("[GodotTogether] Shutting down updater")
	queue_free()

static func ensure_dir_exists(path: String) -> int:
	var dir = path.get_base_dir()
	
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		return DirAccess.make_dir_recursive_absolute(dir)
		
	return OK

static func remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	
	if not dir:
		printerr("Unable to delete %s: %s" % [path, error_string(DirAccess.get_open_error())])
		return
	
	for file in dir.get_files():
		dir.remove(file)
	
	for sub_dir in dir.get_directories():
		remove_dir_recursive(path + "/" + sub_dir)
	
	dir.remove(".")
