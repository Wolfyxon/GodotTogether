@tool
extends Node
class_name GDTRestarter

func _ready():
	EditorInterface.set_plugin_enabled("GodotTogether", false)
	await get_tree().process_frame
	EditorInterface.set_plugin_enabled("GodotTogether", true)
	
	queue_free()