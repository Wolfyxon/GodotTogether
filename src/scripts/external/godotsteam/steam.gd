@tool
extends GDTComponent
class_name GDTSteam

enum SetupStatus {
	OK,
	INTERNAL_ERROR,
	NOT_STARTED,
	NOT_AVAILABLE,
	NO_STEAM_CLIENT,
	STEAM_CLIENT_OUTDATED
}

# The asset store doesn't provide a proper API to get latest version
# Hardcoding seems the safest for now
const DOWNLOAD_URL = "https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/download/8276/"
const DOWNLOAD_SHA256 = "d4358888959a03f4df0c71aafbcdca8f34b8cb9d4522aa5c8454f0e9e3debbf7"
const APP_ID = 480

const INIT_META = "_initialized"

var last_status = SetupStatus.NOT_STARTED
var last_shutdown_time: float = 0.0

# WARNING: Do not use the 'Steam' singleton or any types here directly
#          The script must remain parsable when the godotsteam addon is not installed.

# NOTE: shutdownSteam() function doesn't properly shutdown the SDK and it only breaks
# things. Do not use it.

func _ready() -> void:
	setup()
	report_ready()

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

func setup() -> SetupStatus:
	last_status = setup_steam_api()
	
	if last_status == SetupStatus.OK:
		setup_signals()

	return last_status

func setup_signals() -> void:
	var steam = get_singleton()
	if not steam: return
	
	GDTUtils.try_connect_bulk({
		steam.steam_shutdown: _steam_shutting_down
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
