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
	
	$main/scroll/vbox/updateSigningContainer/updateSigning.main = main

func _on_btn_node_classes_pressed() -> void:
	main.debug.dump_node_classes()

func _on_btn_file_tree_pressed() -> void:
	var paths = GDTFiles.get_file_tree()
	
	for i in paths:
		print(i)

func _on_btn_unsafe_file_tree_pressed() -> void:
	var paths = GDTFiles.get_file_tree("res://", true)
	
	for i in paths:
		print(i)
