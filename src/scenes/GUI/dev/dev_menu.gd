@tool
extends PopupPanel
class_name GDTDevMenu

var main: GodotTogether = null

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not main:
		return
	
	$main/scroll/updateSigningContainer/updateSigning.main = main
