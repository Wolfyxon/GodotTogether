@tool
extends VBoxContainer
class_name GodotTogetherMenu

var main: GodotTogether
var gui: GodotTogetherGUI

@onready var users: GodotTogetherUserList = $session/tabs/Users
@onready var username_input = $sessionInit/pre/username

func _ready() -> void:
	await get_tree().process_frame
	
	if visuals_available():
		main_menu()

func _host() -> void:
	if main:
		var port = $sessionInit/start/host/port/value.value
		var max_clients = $sessionInit/start/host/users/value.value

		var err = main.server.start_hosting(port, max_clients)

		if err:
			gui.alert("Failed to start server: %s" % error_string(err), "Failed to start server")
			return

		main.server.get_server_user().name = username_input.text

	session_menu()
	
	$session/top/status.text = "You are hosting"
	$session/top/end.text = "Stop server"
	

func _join() -> void:
	if main.client:
		main.client.current_join_data.username = username_input.text

		var ip = $sessionInit/start/join/address/ip.text
		var port = $sessionInit/start/join/address/port.value

		var err = main.client.join(ip, port, main.client.current_join_data)
		
		if err:
			gui.alert("Failed to create client: %s" % err)
			return

		if not await main.client.connecting_finished:
			gui.alert("Failed to connect to %s:%s" % [ip, port])
			return

	_joined()

func _joined() -> void:
	session_menu()
	
	$session/top/status.text = "Connected"
	$session/top/end.text = "Disconnect"


func end_session() -> void:
	if main and main.is_session_active():
		main.close_connection()
	
	main_menu()

func session_menu() -> void:
	$sessionInit.hide()
	$session.show()

func main_menu() -> void:
	$sessionInit.show()
	$sessionInit/pre.show()
	
	$sessionInit/start.hide()
	$sessionInit/start/host.hide()
	$sessionInit/start/join.hide()
	$session.hide()

func session_start_menu():
	$sessionInit/start.show()
	$sessionInit/pre.hide()
	# Layout glitch fix
	await get_tree().process_frame
	$sessionInit/start.hide()
	await get_tree().process_frame
	$sessionInit/start.show()
	
func visuals_available() -> bool:
	if not gui: 
		return false
	
	return gui.visuals_available()
