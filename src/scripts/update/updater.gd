@tool
extends GDTComponent
class_name GDTUpdater

const LAST_CHECK_SETTING_PATH = "update/last_check"

const ROOT = "res://addons/GodotTogether"
const DOWNLOAD_DIR = "temp"
const DOWNLOAD_FILE = "update.zip"

const USER_AGENT = "GodotTogether Updater"
#const GITHUB_RELEASE_URL = "https://api.github.com/repos/Wolfyxon/GodotTogether/releases/latest"
const GITHUB_RELEASE_URL = "https://api.github.com/repos/Wolfyxon/release-test/releases/latest"
const GITHUB_AUTHOR_ID = 58263600

const API_TIMEOUT = 10
const DOWNLOAD_TIMEOUT = 0

var http = HTTPRequest.new()

func _ready() -> void:
	add_child(http)

func conditional_check() -> GDTUpdateCheckResult:
	if not is_time_to_check():
		return null
	
	return await check()

func get_current_version() -> String:
	return main.get_plugin_version()

func is_time_to_check() -> bool:
	var last_check = GDTSettings.get_setting(LAST_CHECK_SETTING_PATH)
	var interval = GDTSettings.get_setting("update/check_interval_hours") * 60 * 60
	var now = Time.get_unix_time_from_system()
	
	return now > last_check + interval

func get_target_github_asset(assets: Array) -> Dictionary:
	for asset in assets:
		if not "name" in asset:
			printerr("Missing 'name' field in asset")
			continue
		
		if not asset["name"].ends_with(".zip"):
			continue
		
		if not "browser_download_url" in asset:
			printerr("Missing 'browser_download_url' in asset")
			continue
		
		if not "uploader" in asset:
			printerr("Missing 'uploader' field in asset")
			continue
			
		return asset
	
	return {}

func get_unauthorized_user_warning(user_name: String, version: String) -> String:
	return GDTUtils.join([
		"New release '%s' was uploaded by an unauthorized user '%s'" % [version, user_name],
		"Check the plugin's GitHub and Discord for announcements.",
		"Do not try to update manually, unless said otherwise in a trusted channel!",
		"The plugin releases may have been hijacked!"
	], "\n")

func check() -> GDTUpdateCheckResult:
	if not main:
		printerr("Unable to check for updates: main is null")
		return
	
	print("[GodotTogether] Checking for updates...")
	GDTSettings.set_setting(LAST_CHECK_SETTING_PATH, Time.get_unix_time_from_system())
	
	http.timeout = API_TIMEOUT
	http.download_file = ""
	
	var err = http.request(GITHUB_RELEASE_URL, ["User-Agent: %s" % USER_AGENT])
	
	if err != OK:
		return GDTUpdateCheckResult.err("Unable to send HTTP request %s" % error_string(err))
	
	var params = await http.request_completed
	var code: int = params[1]
	var body_buf: PackedByteArray = params[3]
	var body_str = body_buf.get_string_from_utf8()
	
	if code == 0:
		return GDTUpdateCheckResult.err("No internet connection")
	
	if code == 404:
		var res = GDTUpdateCheckResult.new()
		res.type = GDTUpdateCheckResult.ResultType.RunningLatest
		return res
	
	if code != 200:
		print("Body:\n", body_str)
		return GDTUpdateCheckResult.err("HTTP error %s" % code)
	
	var json_data = JSON.parse_string(body_str)
	
	if not json_data:
		print("Body:\n", body_str)
		return GDTUpdateCheckResult.err("Unable to parse JSON")
	
	if not "name" in json_data:
		return GDTUpdateCheckResult.err("Missing 'name' field in JSON data")
	
	var res = GDTUpdateCheckResult.new()
	res.type = GDTUpdateCheckResult.ResultType.UpdateAvailable
	res.version = json_data["name"]
	
	if res.version == get_current_version():
		res.type = GDTUpdateCheckResult.ResultType.RunningLatest
		return res
	
	if not "author" in json_data:
		return GDTUpdateCheckResult.err("Unable to verify release authenticity. Missing 'author' field")
		
	var author_data = json_data["author"]
	
	if not "id" in author_data:
		return GDTUpdateCheckResult.err("Unable to verify release authenticity. Missing 'id' field under 'author'")
	
	if author_data["id"] != GITHUB_AUTHOR_ID:
		var author_name = "<unknown>"
		
		if "login" in author_data:
			author_name = author_data["login"]
		
		return GDTUpdateCheckResult.err(get_unauthorized_user_warning(author_name, res.version))
	
	if not "assets" in json_data:
		GDTUpdateCheckResult.err("Missing 'assets' field in JSON data")
		return res
	
	var assets = json_data["assets"]
	var asset = get_target_github_asset(assets)
	
	if asset.is_empty():
		return GDTUpdateCheckResult.err("Update file to download not found")
	
	if asset["uploader"]["id"] != GITHUB_AUTHOR_ID:
		var user_name = "<unknown>"
		
		if "login" in asset["uploader"]:
			user_name = asset["uploader"]["login"]
		
		return GDTUpdateCheckResult.err(get_unauthorized_user_warning(user_name, res.version))
	
	res.download_url = asset["browser_download_url"]
	
	return res

func get_download_progress_percent() -> int:
	var size = http.get_body_size()
	
	if size == 0:
		return 0
	
	return (http.get_downloaded_bytes() / size) * 100

func delete_download_zip() -> void:
	var path = ROOT + "/" + DOWNLOAD_DIR
	
	var dir = DirAccess.open(path)
	
	if not dir.file_exists(DOWNLOAD_FILE):
		return
	
	var rm_err = dir.remove(DOWNLOAD_FILE)
	
	if rm_err != OK:
		printerr("Unable to delete old update file: %s: %s" % [DOWNLOAD_FILE, error_string(rm_err)])

func prepare_dir() -> String:
	var dir = DirAccess.open("res://addons/GodotTogether")
	
	if not dir:
		return "Unable to access project directory"
	
	if not dir.dir_exists(DOWNLOAD_DIR):
		var err = dir.make_dir(DOWNLOAD_DIR)
		
		if err != OK:
			return "Unable to create temp directory: %s" % error_string(err) 
	
	return ""

func download_update_zip(url: String) -> String:
	http.timeout = DOWNLOAD_TIMEOUT
	http.download_file = ROOT + "/" + DOWNLOAD_DIR + "/" + DOWNLOAD_FILE
	
	var dir_err = prepare_dir()
	
	if not dir_err.is_empty():
		return dir_err
	
	print("[GodotTogether] Downloading %s to %s" % [url, http.download_file])
	
	delete_download_zip()
	
	http.request(url, ["User-Agent: %s" % USER_AGENT])
	var params = await http.request_completed
	var code = params[1]
	
	if code == 0:
		return "No internet connection"
	
	if code != 200:
		return "HTTP code %s" % code
	
	print("[GodotTogether] Successfully downloaded %s" % http.download_file)
	
	http.download_file = ""
	return ""

func begin_update(update: GDTUpdateCheckResult) -> void:
	if not main:
		return
	
	main.close_connection()
	
	var download_err = await download_update_zip(update.download_url)
	
	if not download_err.is_empty():
		main.gui.alert(download_err, "Error downloading update")
		return
	
	apply_update()

func apply_update() -> void:
	var installer = GDTUpdateInstaller.new()
	var zip_err = installer.open_zip(ROOT + "/" + DOWNLOAD_DIR + "/" + DOWNLOAD_FILE)
	
	if zip_err != OK:
		main.gui.alert("Unable to open update file: %s" % error_string(zip_err), "Error applying update")
		installer.queue_free()
		return
	
	var valid_err = installer.validate()
	
	if not valid_err.is_empty():
		main.gui.alert(valid_err, "Update file is invalid")
		installer.queue_free()
		return
	
	installer.start()
	
	print("[GodotTogether] Shutting down plugin for update")
	main.shutdown()
