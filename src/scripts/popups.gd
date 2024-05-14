extends Node
class_name GodotTogetherPopups

static func _popup(window: Window):
	window.always_on_top = true
	window.unresizable = true
	
	if Engine.is_editor_hint():
		EditorInterface.popup_dialog_centered(window)
	else:
		Engine.get_main_loop().current_scene.add_child(window)
		window.popup_centered()

static func popup_ok(text: String, title := ""):
	var dial = AcceptDialog.new()
	dial.dialog_text = text
	dial.title = title
	dial.dialog_autowrap = true
	
	_popup(dial)
	
	await dial.close_requested
	dial.queue_free()

static func popup_confirm(text: String, title := "") -> bool:
	var dial = ConfirmationDialog.new()
	dial.dialog_text = text
	dial.title = title
	dial.dialog_autowrap = true
	
	_popup(dial)

	dial.set_meta("confirmed", false)
	
	dial.confirmed.connect(func():
		dial.set_meta("confirmed", true)
	)
	
	await dial.visibility_changed
	await Engine.get_main_loop().physics_frame
	
	dial.queue_free()
	
	return dial.get_meta("confirmed")

static func popup_confirm_action(text: String, callback: Callable, title := "") -> bool:
	var res = await popup_confirm(text, title)
	if res: callback.call()
	
	return res
