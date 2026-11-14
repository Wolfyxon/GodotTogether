@tool
extends VBoxContainer
class_name GDTMenu

var main: GodotTogether
var gui: GodotTogetherGUI

@onready var update_btn = $topBar/update
@onready var version_warning = $topBar/versionWarning

@onready var steam_setup = $steamSetup
@onready var steam_lobbies = $sessionInit/start/join/steam/lobbies/lobbyVbox

@onready var con_method_input = $sessionInit/pre/method/dropdown

@onready var username_input = $sessionInit/pre/username
@onready var session_init_cover = $sessionInit/cover
@onready var session_cancel = $sessionInit/cover/vbox/btnCancel

@onready var join_enet_ip_input = $sessionInit/start/join/enet/address/ip
@onready var join_enet_port_input =  $sessionInit/start/join/enet/address/port
@onready var join_enet_password_input = $sessionInit/start/join/enet/password

@onready var users: GDTUserList = $session/tabs/Users
@onready var server_settings_tab = $"session/tabs/Server settings"

@onready var host_settings = $sessionInit/start/host/settings

var cover_timeout: float = -1

func _ready() -> void:
	await get_tree().process_frame
	
	if main:
		$sessionInit/pumpkin.visible = main.extras and main.extras.is_halloween()
		steam_setup.main = main
		steam_lobbies.main = main
		
		main_menu()
		
		main.updater.update_detected.connect(_update_available, CONNECT_ONE_SHOT)
		
		main.client.disconnected.connect(func():
			await get_tree().process_frame
			session_start_menu("join")
		)
		
		main.steam.lobby_join_request.connect(join_steam)
		steam_lobbies.lobby_join_request.connect(join_steam)

	if visuals_available():
		set_session_init_cover()
		check_engine_version()
		
		update_btn.visible = false
		
		var settings = main.get_settings()
		settings.settings_changed.connect(_settings_changed)
		
		settings.make_setting_control(username_input, "username")
		settings.make_setting_control(join_enet_ip_input, "last_connection/ip")
		settings.make_setting_control(join_enet_port_input, "last_connection/port")

		_settings_changed()

func _process(_delta: float) -> void:
	if not visuals_available():
		return
	
	var timer_label = session_init_cover.get_node("vbox/timer")
	
	if cover_timeout != -1:
		var time = Time.get_unix_time_from_system()
		var time_diff = max(cover_timeout - time, 0)
		
		timer_label.text = str(int(time_diff))
		timer_label.visible = true
	else:
		timer_label.visible = false

func _settings_changed() -> void:
	$topBar/devMenu.visible = main.get_settings().get_setting("dev/menu_button")

func _update_available(update: GDTUpdateCheckResult) -> void:
	update_btn.text = "Update to v.%s" % update.version
	update_btn.visible = true
	update_btn.pressed.connect(_query_update)
	
func _query_update() -> void:
	if await gui.confirm("Download and install the latest update?"):
		main.updater.begin_update()

func _host() -> void:
	if not main: return

	set_session_init_cover("Starting server...")
	
	match main.connection_method:
		GodotTogether.ConnectionMethod.ENET:
			await _host_enet()
		GodotTogether.ConnectionMethod.STEAM:
			await _host_steam()
	
	if not main.is_session_active():
		printerr("Session not reported as active")
		return
	
	server_settings_tab.load_settings()
	main.dual.get_server_user().name = username_input.text

	session_menu()
	
	$session/top/status.text = "You are hosting"
	$session/top/end.text = "Stop server"
	$session/top/end.tooltip_text = "Stop hosting, ending the session for everyone"

func _host_enet() -> void:
	var port = host_settings.port_input.value
	var max_clients = host_settings.max_users_input.value
	
	session_cancel.visible = false
	
	await RenderingServer.frame_post_draw
	
	var err = main.server.start_hosting_enet(port, max_clients)
	
	if err:
		set_session_init_cover()
		gui.alert(GDTUtils.join([
			"Unable to start server.",
			"Make sure a GodotTogether server is not already running in another Godot instance",
			"and no other application is using this port.",
			"Error code: %s" % error_string(err),
		], "\n"), "Failed to start server")
		return

func _prepare_connection() -> void:
	main.client.current_join_data.username = username_input.text
	main.client.current_join_data.password = join_enet_password_input.text
	session_cancel.visible = true

func _handle_connecting() -> void:
	set_session_init_cover("Connected, waiting for server reply...")
	set_session_init_timeout(GDTServer.APPROVE_TIMEOUT)
	
	await main.client.connection_acknowledged
	
	set_session_init_cover("Waiting for host's approval...")
	set_session_init_timeout(GDTServer.APPROVE_TIMEOUT)
	
	await main.client.auth_succeed
	
	if not main.client.is_active():
		main.get_gui().alert("Connection finished, but client does not report activity. This is a bug.")
		main.close_connection()
		set_session_init_cover()
		return
	
	while not main.client.is_fully_synced and main.client.is_active():
		if main.file_sync.last_received_file:
			set_session_init_cover(
				"%s (%s / %s)" % [
					main.file_sync.last_received_file,
					String.humanize_size(main.file_sync.total_received_bytes),
					String.humanize_size(main.client.server_data.get_project_download_size())
				]
			)
		else:
			set_session_init_cover("Starting project download...")
		
		await get_tree().process_frame
	
	if not main.client.is_active():
		return
	
	_joined()

func _join_enet() -> void:
	var ip: String = join_enet_ip_input.text
	var port: int = join_enet_port_input.value
	
	if not ip.strip_edges():
		gui.alert("Enter a valid IP address or domain.", "Invalid address")
		return
	
	_prepare_connection()
	
	set_session_init_cover("Trying to connect...")
	set_session_init_timeout(main.client.get_timeout_seconds())
	
	var err = main.client.join_enet(ip, port, main.client.current_join_data)
	
	if err != OK:
		set_session_init_cover()
		gui.alert(
			GDTUtils.join([
				"Unable to begin connection.",
				"Make sure the IP and port is valid.",
				"Error code: %s" % error_string(err),
			], "\n"),
			"Failed to start client"
		)

		return
		
	if not await main.client.connecting_finished:
		if main.client.connection_cancelled:
			set_session_init_cover()
			return
		
		set_session_init_cover()
		gui.alert(
			GDTUtils.join([
				"Connection to %s:%s timed out." % [ip, port],
				"Make sure that:",
				"- You entered the right IP and port",
				"- Both you and host are in the same local or tunnelled network",
				"- Your firewall settings aren't blocking the used port",
				"- Godot can access the internet, or your network",
				"",
				"If you're using a tunnel (like Tailscale or ZeroTier):",
				"- Make sure you entered the IP supplied by the tunnel network, not your machine",
				"- Both you and the host are authorized to access the network",
				"- You didn't exceed your pricing tier limits",
				"",
				"You can verify connectivity between you and the host by running:",
				"	ping enter.their.ip.address.here",
				"in your terminal (cmd on Windows)."
			], "\n"),
			"Failed to connect"
		)

		return
	
	_handle_connecting()

func join_steam(lobby_id: int) -> void:
	set_session_init_cover("Joining lobby via Steam...")
	
	_prepare_connection()
	
	var err = await main.client.join_steam_async(lobby_id)

	if err != GDTSteam.JoinResult.OK:
		set_session_init_cover()
		
		# TODO: Error to string
		main.get_gui().alert("Failed to join lobby. Code: %s" % err)
		
		return
	
	if not await main.client.connecting_finished:
		set_session_init_cover()
		
		if main.client.connection_cancelled:
			return
		
		main.gui.alert("Failed to establish connection in lobby.")
		main.steam.leave_lobby()
	
	_handle_connecting()

func _host_steam() -> void:
	var max_clients = host_settings.max_users_input.value
	
	set_session_init_cover("Connecting to Steam...")
	
	var err = await main.server.start_hosting_steam_async(max_clients)
	
	if err != GDTSteam.Result.OK:
		set_session_init_cover()
		gui.alert("Unable to create lobby. Error: %s" % err)
		return
		
	

func _joined() -> void:
	session_menu()
	
	$session/top/status.text = "Connected"
	$session/top/end.text = "Disconnect"
	$session/top/end.tooltip_text = "Leave the session."

func set_session_init_cover(text: String = "") -> void:
	if text == "":
		session_init_cover.hide()
		return
	
	session_init_cover.get_node("vbox/title").text = text
	session_init_cover.get_node("vbox/timer").text = ""
	cover_timeout = -1
	
	session_init_cover.show()

func set_session_init_timeout(seconds: float) -> void:
	cover_timeout = Time.get_unix_time_from_system() + seconds

func end_session() -> void:
	if main and main.is_session_active():
		main.close_connection()
	
	main_menu()

func session_menu() -> void:
	set_session_init_cover()
	$sessionInit.hide()
	$session.show()

func main_menu() -> void:
	$sessionInit.show()
	$sessionInit/pre.show()
	
	$sessionInit/start.hide()
	$sessionInit/start/host.hide()
	$sessionInit/start/join.hide()
	$session.hide()
	
	set_session_init_cover()
	host_settings.load_settings()

func session_start_menu(tab: String = "") -> bool:
	set_session_init_cover()
	
	if not await setup_connection_method():
		return false
	
	$sessionInit/start.show()
	$sessionInit/pre.hide()
	$sessionInit.show()
	$session.hide()

	$sessionInit/start/join.hide()
	$sessionInit/start/host.hide()
	
	if tab == "join":
		$sessionInit/start/join.show()
	elif tab == "host":
		$sessionInit/start/host.show()

	# Layout glitch fix
	await get_tree().process_frame
	$sessionInit/start.hide()
	await get_tree().process_frame
	$sessionInit/start.show()
	
	return true

func setup_connection_method() -> bool:
	main.connection_method = con_method_input.selected
	
	if main.connection_method != GodotTogether.ConnectionMethod.STEAM:
		return true
	
	if not main.steam.addon_exists():
		set_session_init_cover()
		
		if await main.get_gui().confirm("GodotSteam needs to be installed. Install now?"):
			main.steam.installer.install()
		
		return false
	
	if not main.steam.is_installed_enabled():
		main.get_gui().alert("GodotSteam seems to be installed but it can't be accessed. Try restarting Godot or redownlaoding GodotSteam.")
		return false
	
	set_session_init_cover("Initializing Steam...")
	
	var status = main.steam.setup()
	
	if status != GDTSteam.SetupStatus.OK:
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		
		main_menu()
		gui.alert(GDTSteam.setup_status_to_string(status), "Failed to initialize Steam")
		return false
		
	set_session_init_cover()
	return true

func visuals_available() -> bool:
	if not gui: 
		return false
	
	return gui.visuals_available()

func check_engine_version() -> void:
	var info = Engine.get_version_info()
	var supported_info = GodotTogether.SUPPORTED_ENGINE_VERSION
	
	if info["status"] != "stable":
		version_warning.visible = true
		version_warning.text = "Only supported on Godot stable"
		return
	
	if (
		info["major"] != supported_info[0] or
		info["minor"] != supported_info[1] or
		info["patch"] != supported_info[2]
	):
		version_warning.visible = true
		version_warning.text = "Only supported on Godot %s.%s.%s" % [supported_info[0], supported_info[1], supported_info[2]]
		return
	
	version_warning.visible = false

func _on_btn_cancel_pressed() -> void:
	if main:
		main.close_connection()
		set_session_init_cover()

func _on_restart_pressed() -> void:
	if main:
		if main.server.is_active():
			main.server.broadcast_restart()
		else:
			main.server.broadcast_restart.rpc_id(1)

func _on_update_timeout() -> void:
	if visuals_available():
		$session/top/restart.visible = main.get_settings().get_setting("dev/restart_broadcast")

func _on_join_pressed() -> void:
	if not await session_start_menu():
		return
	
	$sessionInit/start/join.show()
	
	if main.connection_method == GodotTogether.ConnectionMethod.ENET:
		$sessionInit/start/join/steam.hide()
		$sessionInit/start/join/enet.show() 
	elif main.connection_method == GodotTogether.ConnectionMethod.STEAM:
		steam_lobbies.load_lobbies()
		$sessionInit/start/join/steam.show()
		$sessionInit/start/join/enet.hide()
