@tool
extends GDTComponent
class_name GDTSteam

signal lobby_join_request(lobby_id: int)

enum SetupStatus {
	OK,
	INTERNAL_ERROR,
	NOT_STARTED,
	NOT_AVAILABLE,
	NO_STEAM_CLIENT,
	STEAM_CLIENT_OUTDATED
}

enum Result {
	NONE,
	OK,
	FAIL,
	NO_CONNECTION,
	TIMEOUT,
	LIMIT_EXCEEDED,
	ACCESS_DENIED
}

enum JoinResult {
	# From Steam API
	NONE,
	OK = 1,
	NOT_FOUND,
	NOT_ALLOWED,
	FULL,
	ERROR,
	BANNED,
	LIMITED_ACCOUNT,
	CLAN_DISABLED,
	COMMUNITY_BAN,
	BLOCKED_YOU,
	BLOCKED,
	RATE_LIMIT = 15,
}

const SETUP_STATUS_MAP = {
	SetupStatus.OK: "Ok",
	SetupStatus.INTERNAL_ERROR: "Internal error. This is a bug.",
	SetupStatus.NOT_STARTED: "Setup not started",
	SetupStatus.NOT_AVAILABLE: "Steam addon is not available",
	SetupStatus.NO_STEAM_CLIENT: "Steam is not running",
	SetupStatus.STEAM_CLIENT_OUTDATED: "Steam is outdated"
}

const APP_ID = 480
const INIT_META = "_initialized"

@onready var installer: GDTSteamInstaller = null

var last_status = SetupStatus.NOT_STARTED
var last_shutdown_time: float = 0.0
var current_lobby_id: int = 0
var peer: MultiplayerPeer = null

# WARNING: Do not use the 'Steam' singleton or any types here directly
#          The script must remain parsable when the godotsteam addon is not installed.

# NOTE: shutdownSteam() function doesn't properly shutdown the SDK and it only breaks
# things. Do not use it.

func _ready() -> void:
	installer = GDTSteamInstaller.new()
	installer.main = main
	add_child(installer)
	
	report_ready()

func _exit_tree() -> void:
	if installer:
		installer.queue_free()
	
	leave_lobby()

func _process(_delta: float) -> void:
	if is_ready():
		var steam = get_singleton()
		if not steam: return
		
		steam.run_callbacks()

func _steam_shutting_down() -> void:
	# This signal fires twice for some reason
	var now = Time.get_unix_time_from_system()
	
	if now - last_shutdown_time < 0.1:
		return
	
	last_shutdown_time = now
	
	var msg = GDTUtils.join([
		"Steam is shutting down!",
		"You must completely close Godot, otherwise it will not finish shutting down."
	], "\n")
	
	push_warning("[GodotTogether] %s" % msg)
	
	var gui = main.get_gui()
	
	if gui:
		gui.alert(msg)

func _invitied(inviter: int, lobby: int, _game: int) -> void:
	print("[GodotTogether:Steam] You were invited by %s to lobby %s" % [inviter, lobby])

func _join_requested(lobby_id: int, _friend_id: int) -> void:
	print("[GodotTogether:Steam] You are requesting to join lobby %s" % lobby_id)
	lobby_join_request.emit(lobby_id)

func leave_lobby():
	var steam = get_singleton()
	
	if current_lobby_id != 0:
		steam.leaveLobby(current_lobby_id)
		current_lobby_id = 0

func create_peer() -> MultiplayerPeer:
	if peer:
		return peer
	
	peer = ClassDB.instantiate("SteamMultiplayerPeer")
	return peer

func setup() -> SetupStatus:
	last_status = setup_steam_api()
	
	if last_status == SetupStatus.OK:
		setup_signals()

	if not create_peer():
		printerr("Unable to create SteamMultiplayerPeer peer")
		return SetupStatus.INTERNAL_ERROR
	
	return last_status

func setup_signals() -> void:
	var steam = get_singleton()
	if not steam: return
	
	GDTUtils.try_connect_bulk({
		steam.steam_shutdown: _steam_shutting_down,
		steam.lobby_invite: _invitied,
		steam.join_requested: _join_requested
	})

func setup_steam_api() -> SetupStatus:
	if not is_installed_enabled(): 
		return SetupStatus.NOT_AVAILABLE
	
	var steam = get_singleton()
	
	if not steam:
		GDTUtils.printerr_stack("Steam addon detected, but 'Steam' singleton doesn't exist.")
		return SetupStatus.INTERNAL_ERROR
	
	if steam.has_meta(INIT_META):
		return SetupStatus.OK
	
	var res: Dictionary = steam.steamInitEx(APP_ID, true)
	
	if not res:
		GDTUtils.printerr_stack("Steam initialization response is empty")
		return SetupStatus.INTERNAL_ERROR
	
	var status: int = res["status"]
	
	if status != steam.STEAM_API_INIT_RESULT_OK:
		if status == steam.STEAM_API_INIT_RESULT_NO_STEAM_CLIENT:
			return SetupStatus.NO_STEAM_CLIENT
		if status == steam.STEAM_API_INIT_RESULT_VERSION_MISMATCH:
			return SetupStatus.STEAM_CLIENT_OUTDATED
		
		GDTUtils.printerr_stack("Steam setup failed with status: %s" % status)
		return SetupStatus.INTERNAL_ERROR
	
	steam.set_meta(INIT_META, true)
	steam.run_callbacks()
	
	return SetupStatus.OK

func create_lobby_async(max_clients := 10) -> Result:
	var steam = get_singleton()
	
	if not steam:
		GDTUtils.printerr_stack("Attempt to create lobby when Steam doesn't exist") 
		return Result.NONE
	
	var start = func():
		await get_tree().process_frame
		steam.createLobby(steam.LOBBY_TYPE_FRIENDS_ONLY, max_clients)
	start.call()
	
	var res = await steam.lobby_created
	var status = res[0]
	current_lobby_id = res[1]
	
	if status != steam.RESULT_OK:
		printerr("Failed to create Steam lobby. Error: %s" % status)
		return Result.FAIL
	
	var peer_err = peer.host_with_lobby(current_lobby_id)
	
	if peer_err != OK:
		printerr("Unable to connect host peer to lobby. Error: %s" % peer_err)
		return Result.FAIL
	
	multiplayer.multiplayer_peer = peer
	
	return Result.OK

func join_lobby_async(lobby_id: int) -> JoinResult:
	var steam = get_singleton()
	
	if not steam:
		GDTUtils.printerr_stack("Attempt to join lobby when Steam doesn't exist")  
		return JoinResult.NONE
	
	steam.joinLobby.call_deferred(lobby_id)
	
	#lobby: int, permissions: int, locked: bool, response: int
	var res = await steam.lobby_joined 
	var join_response = res[3]
	
	if join_response != JoinResult.OK:
		printerr("Steam error: %s" % join_response)
		return join_response
	
	var peer_err = peer.connect_to_lobby(lobby_id)
	
	if peer_err != OK:
		printerr("Peeer error: %s" % peer_err)
		leave_lobby()
		return JoinResult.ERROR
	
	multiplayer.multiplayer_peer = peer
	
	return JoinResult.OK

func addon_exists() -> bool:
	return GDTSteamInstaller.addon_exists()

func is_installed_enabled() -> bool:
	return Engine.has_singleton("Steam")

func get_local_username() -> String:
	var steam = get_singleton()
	if not steam: return ""
	
	return steam.getFriendPersonaName(steam.current_steam_id)

func is_ready() -> bool:
	return last_status == SetupStatus.OK

func get_singleton() -> Object:
	if not is_installed_enabled(): 
		return
	
	return Engine.get_singleton("Steam")

func get_friend_lobbies() -> Array:
	var res = []
	
	var steam = get_singleton()
	
	if not steam:
		GDTUtils.printerr_stack("Trying to get friend lobbies when Steam doesn't exist")
		return res
	
	for i in steam.getFriendCount():
		var id: int = steam.getFriendByIndex(i, steam.FRIEND_FLAG_IMMEDIATE)
		var game_info: Dictionary = steam.getFriendGamePlayed(id)
		if not game_info: continue
		
		if game_info["id"] != steam.getAppID() and not main.settings.get_setting("dev/steam/show_other_app_lobbies"): 
			continue
		
		var lobby_id = game_info["lobby"]
		if typeof(lobby_id) != TYPE_INT: continue
		
		res.append({
			"user_id": id,
			"user_name": steam.getFriendPersonaName(id),
			"lobby_id": lobby_id
		})
	
	return res

static func setup_status_to_string(status: SetupStatus) -> String:
	if status < 0 or status > SetupStatus.size():
		return "Unknown error"
	
	return SETUP_STATUS_MAP[status]
