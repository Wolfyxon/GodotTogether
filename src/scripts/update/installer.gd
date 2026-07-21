@tool
extends Node
class_name GDTUpdateInstaller

# IMPORTANT: Do not use any GodotTogether classes here. 
# This script must be independent

var zip_path: String = ""
var zip: ZIPReader

func _ready() -> void:
	await get_tree().process_frame # Wait for shutdown
	
	print("[GodotTogether] Applying update")

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
