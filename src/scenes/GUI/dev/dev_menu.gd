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
	
	$main/scroll/vbox/profiling/vbox.main = main
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

func _on_btn_scanned_files_pressed() -> void:
	var paths = main.file_sync.file_hashes
	
	for i in paths:
		print(i)

func _on_btn_execute_pressed() -> void:
	var expr = Expression.new()
	var source_code = $main/scroll/vbox/exec/vbox/code.text
	var err = expr.parse(source_code)
	
	if err != OK:
		printerr(expr.get_error_text())
		return
	
	var start = Time.get_unix_time_from_system()
	var res = expr.execute([], self)
	var end = Time.get_unix_time_from_system()
	
	if not expr.has_execute_failed():
		print("Code result: %s" % res)
	
	print("Took: %s s" % str(end - start)) # why doesn't it automatically convert  to string here?
