@tool
extends VBoxContainer

var main: GodotTogether = null

func _on_visibility_changed() -> void:
	if not visible: return
	if not main: return
	
	$available.text = "Installed: %s" % main.steam.is_installed_enabled()
	$appId.text = "App ID: %s" % main.steam.APP_ID
	$setupStatus.text = "Setup status: %s (%s)" % [main.steam.last_status, GDTSteam.SetupStatus.keys()[main.steam.last_status]]
	$username.text = "Username: %s" % main.steam.get_local_username()
	$lobbyId.text = "Current lobby: %s" % main.steam.current_lobby_id
