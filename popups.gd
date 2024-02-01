extends Node
class_name GodotTogetherPopups

func _popup(window:Window):
	if Engine.is_editor_hint():
		EditorInterface.popup_dialog_centered(window)
	else:
		get_tree().current_scene.add_child(window)
		window.popup_centered()

func popup_ok(text:String, title := ""):
	var dial = AcceptDialog.new()
	dial.dialog_text = text
	dial.title = title
	dial.dialog_autowrap = true
	
	_popup(dial)
	
	await dial.close_requested
	dial.queue_free()
