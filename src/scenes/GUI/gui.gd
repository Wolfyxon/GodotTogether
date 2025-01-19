@tool
extends PopupPanel
class_name GodotTogetherGUI

var main: GodotTogether

@onready var username_input = $main/sessionInit/pre/username

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
	if main:
		var port = $main/sessionInit/start/host/port/value.value
		var max_clients = $main/sessionInit/start/host/users/value.value

		var err = main.server.start_hosting(port, max_clients)

		if err:
			alert("Failed to start server: %s" % error_string(err), "Failed to start server")
			return

		main.server.get_server_user().name = username_input.text

	session_menu()
	
	$main/session/top/status.text = "You are hosting"
	$main/session/top/end.text = "Stop server"
	

func _join() -> void:
	if main.client:
		main.client.current_join_data.username = username_input.text

		var ip = $main/sessionInit/start/join/address/ip.text
		var port = $main/sessionInit/start/join/address/port.value

		var err = main.client.join(ip, port, main.client.current_join_data)
		
		if err:
			alert("Failed to create client: %s" % err)
			return

		if not await main.client.connecting_finished:
			alert("Failed to connect to %s:%s" % [ip, port])
			return

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
