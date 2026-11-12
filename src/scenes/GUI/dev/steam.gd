@tool
extends VBoxContainer

var main: GodotTogether = null

var is_set_up = false

func _on_visibility_changed() -> void:
	if not visible: return
	if not main: return
	
	$available.text = "Installed: %s" % main.steam.is_installed_enabled()
	$appId.text = "App ID: %s" % main.steam.APP_ID
	$setupStatus.text = "Setup status: %s (%s)" % [main.steam.last_status, GDTSteam.SetupStatus.keys()[main.steam.last_status]]
	$username.text = "Username: %s" % main.steam.get_local_username()
	$lobbyId.text = "Current lobby: %s" % main.steam.current_lobby_id

	if not is_set_up:
		is_set_up = true
		
		main.settings.make_setting_control($showOtherApps, "dev/steam/show_other_app_lobbies")

func _on_btn_download_install_pressed() -> void:
	if not await main.get_gui().confirm("Download and install GodotSteam?"):
		return
	
	main.steam.installer.install()

func _on_btn_install_existing_pressed() -> void:
	main.steam.installer.install_existing()
