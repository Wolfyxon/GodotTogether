@tool
extends PopupPanel
class_name GodotTogetherGUI

var main: GodotTogether

func _ready() -> void:
	if not visuals_available(): return
	
	main_menu()
	$about/scroll/vbox/version.text = "Version: " + GodotTogether.VERSION

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		visible = true
		
	if visuals_available():
		if Input.is_action_just_pressed("ui_cancel") and $main/sessionInit/start.visible:
			main_menu()

func _host() -> void:
	session_menu()
	
	$main/session/top/status.text = "You are hosting"
	$main/session/top/end.text = "Stop server"
	

func _join() -> void:
	# TODO: Connection checking and stuff
	_joined()

func _joined() -> void:
	session_menu()
	
	$main/session/top/status.text = "Connected"
	$main/session/top/end.text = "Disconnect"

func alert(text: String, title := "") -> AcceptDialog:
	var popup = AcceptDialog.new()
	
	popup.dialog_text = text
	popup.title = title
	popup.always_on_top = true

	add_child(popup)

	if main:
		EditorInterface.popup_dialog_centered(popup)
	else:
		popup.popup_centered()

	popup.canceled.connect(popup.queue_free)
	popup.confirmed.connect(popup.queue_free)

	return popup

func end_session() -> void:
	if main and main.is_session_active():
		main.close_connection()
	
	main_menu()

func main_menu() -> void:
	$main/sessionInit.visible = true
	$main/sessionInit/pre.visible = true
	
	$main/sessionInit/start.visible = false
	$main/sessionInit/start/host.visible = false
	$main/sessionInit/start/join.visible = false
	$main/session.visible = false

func session_start_menu():
	$main/sessionInit/start.visible = true
	$main/sessionInit/pre.visible = false
	# Layout glitch fix
	await get_tree().process_frame
	$main/sessionInit/start.visible = false
	await get_tree().process_frame
	$main/sessionInit/start.visible = true

func session_menu() -> void:
	$main/sessionInit.visible = false
	$main/session.visible = true

func visuals_available() -> bool:
	return main or not Engine.is_editor_hint() 
