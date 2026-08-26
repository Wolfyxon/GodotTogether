@tool
extends GDTComponent
class_name GDTUpdater

signal update_detected

const LAST_CHECK_SETTING_PATH = "update/last_check"

const ROOT = "user://"
const DOWNLOAD_DIR = "GodotTogetherUpdater"
const DOWNLOAD_FILE = "update.zip"
const ZIP_PATH = ROOT + "/" + DOWNLOAD_DIR + "/" + DOWNLOAD_FILE

const USER_AGENT = "GodotTogether Updater"
const GITHUB_RELEASE_URL = "https://api.github.com/repos/Wolfyxon/release-test/releases/latest"
const GITHUB_AUTHOR_ID = 58263600

const RELEASE_KEY_TEXT = "
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjfLVr8zDUH2yL5JXcr1T
hUqppO4vKi4aQjIT8vV/AW5kNqbBl+J+QFrW95um3loVRra8NnyBDVJBH1gYvMUZ
OWAVxdMfdvwQ2qvIRRLEi7T9t0S9zIFUZfoGqBYN8ALftGpLAmllMspyjVr3lk4d
jB3T3l1weoax/IC+g2cmuvuYsvzSiZMhjBmoIW1OF/fpZNzz3/T7EayQbPkLjo7/
Ulp/bVRM+SMBoaPySYtJp3hqXwrJxqt/XZz9xQs6qckz0nvCqwRccEFDs/qPUOHZ
mF7T/9efgqSVEwMOsSrRkg3kcrScnLfZ2oqKZUAAkY62D8ypMgoCGOna67pQWUaE
gaortc6dFuLCOTqBLBUfzBmb6lQmbO6wo5jp/8tKsQr21ZONRfHOJqEvSH3/G4yE
eJFB5CeakhBvWgk1EKpsD3sjXsoV9Be6FKTAgoqgbFDUOCFxNwCjfoKmCyWE+G/B
EDwBECdEi5N7UMTXbAxuoYy9WQsPxBcPNJW1aqZayn1fT+x3jNy8VdGUzixO+Twv
iBq705N+fdXRavu1+5J+GVuddGvqu69ny3ZhQZqIQLnhHuEwjk3HSrpUnT8diGZT
KfgFSocVeaCqDxbGVv8tXNNDQ7Sr8ccmVwC4KrYVc2OWvcUvs8PRaM87f1kaqEv5
lCnHIepelFBT4a6gPIbRX+sCAwEAAQ==
-----END PUBLIC KEY-----
"

const API_TIMEOUT = 10
const DOWNLOAD_TIMEOUT = 0

var crypto = Crypto.new()
var _release_key: CryptoKey
var http = HTTPRequest.new()
var latest_result: GDTUpdateCheckResult = null

func _ready() -> void:
	add_child(http)

func get_key() -> CryptoKey:
	if _release_key:
		return _release_key
		
	var key = CryptoKey.new()
	var err = key.load_from_string(RELEASE_KEY_TEXT, true)
	
	if err != OK:
		printerr("Unable to load key. Code: %s"  % err)
		return
	
	return key

func sign_hash(private_key_text: String, hash_text: String) -> PackedByteArray:
	var key = CryptoKey.new()
	var err = key.load_from_string(private_key_text)
	
	if err != OK:
		printerr("Unable to load private key. Code: %s"  % err)
		return []
	
	var hash = hash_text.hex_decode()
	
	if hash.is_empty():
		printerr("Unable to decode hash")
		return []
	
	var buf = crypto.sign(HashingContext.HASH_SHA256, hash, key)
	
	return buf

func sign_data(private_key_text: String, data: PackedByteArray) -> PackedByteArray:
	var hash = GDTUtils.sha256_of_buffer(data)
	
	return sign_hash(private_key_text, hash)

func verify_hash(hash: String, signature_buf: PackedByteArray) -> bool:
	var hash_buf = hash.hex_decode()
	var key = get_key()
	
	return crypto.verify(HashingContext.HASH_SHA256, hash_buf, signature_buf, key)

func verify_data(data: PackedByteArray, signature_buf: PackedByteArray) -> bool:
	return verify_hash(GDTUtils.sha256_of_buffer(data), signature_buf)

func check_cached() -> GDTUpdateCheckResult:
	var cached = GDTUpdateCheckResult.get_from_settings()
	
	if not cached:
		latest_result = GDTUpdateCheckResult.status_latest()
		return latest_result
		
	if cached.version != get_current_version():
		cached.type = GDTUpdateCheckResult.ResultType.UpdateAvailable
	else:
		cached.type = GDTUpdateCheckResult.ResultType.RunningLatest
	
	latest_result = cached
	_check_result()
	
	return cached

func conditional_check() -> GDTUpdateCheckResult:
	if is_time_to_check():
		await check()
		
		if latest_result:
			return
	
	check_cached()
	
	return latest_result

func _check_result() -> void:
	if not latest_result:
		return
	
	if latest_result.type == GDTUpdateCheckResult.ResultType.UpdateAvailable:
		update_detected.emit(latest_result)
		print("[GodotTogether] Update detected! %s" % latest_result.version)

func get_current_version() -> String:
	return main.get_plugin_version()

func is_time_to_check() -> bool:
	var last_check = GDTSettings.get_setting(LAST_CHECK_SETTING_PATH)
	var interval = GDTSettings.get_setting("update/check_interval_hours") * 60 * 60
	var now = Time.get_unix_time_from_system()
	
	return now > last_check + interval

func validate_github_asset(asset: Dictionary) -> bool:
	if not "name" in asset:
		printerr("Missing 'name' field in asset")
		return false
	
	if not "browser_download_url" in asset:
		printerr("Missing 'browser_download_url' in asset")
		return false
	
	if not "uploader" in asset:
		printerr("Missing 'uploader' field in asset")
		return false
		
	return true

func get_target_github_asset(assets: Array) -> Dictionary:
	for asset in assets:
		if not validate_github_asset(asset):
			continue
		
		if not asset["name"].ends_with(".zip"):
			continue
		
		return asset
	
	return {}

func get_signature_github_asset(assets: Array) -> Dictionary:
	for asset in assets:
		if not validate_github_asset(asset):
			continue
		
		if not asset["name"].ends_with(".gdsig"):
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
	var res = await _check_from_api()
	
	latest_result = res
	_check_result()
	
	if not res or res.type == GDTUpdateCheckResult.ResultType.RunningLatest:
		print("[GodotTogether] No updates available")
	
	latest_result.save_to_settings()
	
	return res

func _check_from_api() -> GDTUpdateCheckResult:
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
	var download_asset = get_target_github_asset(assets)
	var sign_asset = get_signature_github_asset(assets)
	
	if download_asset.is_empty():
		return GDTUpdateCheckResult.err("Update file to download not found. Please report this")
	
	if sign_asset.is_empty():
		return GDTUpdateCheckResult.err("Update signature not found. The update cannot be verified. Please report this.")
	
	if download_asset["uploader"]["id"] != GITHUB_AUTHOR_ID:
		var user_name = "<unknown>"
		
		if "login" in download_asset["uploader"]:
			user_name = download_asset["uploader"]["login"]
		
		return GDTUpdateCheckResult.err(get_unauthorized_user_warning(user_name, res.version))
	
	var sig_request_err = await request_signature(res, sign_asset["browser_download_url"])
	
	if sig_request_err:
		return GDTUpdateCheckResult.err(sig_request_err)
	
	res.download_url = download_asset["browser_download_url"]
	
	return res

func request_signature(update: GDTUpdateCheckResult, url: String) -> String:
	http.timeout = API_TIMEOUT
	http.download_file = ""
	
	var err = http.request(url, ["User-Agent: %s" % USER_AGENT])
	
	if err != OK:
		return "Unable to request signature: %s" % err
	
	var params = await http.request_completed
	var code: int = params[1]
	var body_buf: PackedByteArray = params[3]
	
	if code == 0:
		return "No internet connection"
	
	if code != 200:
		return "Could not request signature. Code %s" % code
	
	if not body_buf:
		return "Signature is empty. Please report this"
	
	update.signature = body_buf
	
	return ""

func get_download_progress_percent() -> int:
	var size = http.get_body_size()
	
	if size == 0:
		return 0
	
	return (http.get_downloaded_bytes() / size) * 100

func delete_download_zip() -> void:
	var path = ROOT + "/" + DOWNLOAD_DIR
	
	var dir = DirAccess.open(path)
	
	if not dir:
		return
	
	if not dir.file_exists(DOWNLOAD_FILE):
		return
	
	var rm_err = dir.remove(DOWNLOAD_FILE)
	
	if rm_err != OK:
		printerr("Unable to delete old update file: %s: %s" % [DOWNLOAD_FILE, error_string(rm_err)])

func prepare_dir() -> String:
	var dir = DirAccess.open(ROOT)
	
	if not dir:
		return "Unable to access project directory"
	
	if not dir.dir_exists(DOWNLOAD_DIR):
		var err = dir.make_dir(DOWNLOAD_DIR)
		
		if err != OK:
			return "Unable to create temp directory: %s" % error_string(err) 
	
	return ""

func download_update_zip(url: String) -> String:
	http.timeout = DOWNLOAD_TIMEOUT
	http.download_file = ZIP_PATH
	
	var dir_err = prepare_dir()
	
	if not dir_err.is_empty():
		return dir_err
	
	print("[GodotTogether] Downloading %s to %s" % [url, http.download_file])
	
	delete_download_zip()
	
	var prog = main.gui.progress("Downloading")
	prog.bind_to_http_download(http)
	
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

func begin_update(update: GDTUpdateCheckResult = null) -> void:
	if not main:
		return
	
	main.close_connection()
	
	if not update:
		update = latest_result
		
	if not update:
		printerr("Update data not available. Call check() or specify GDTUpdateCheckResult")
		return
	
	var download_err = await download_update_zip(update.download_url)
	
	if not download_err.is_empty():
		alert(download_err, "Error downloading update")
		return
	
	if not verify_update(update):
		return
	
	apply_update()

func verify_update(update: GDTUpdateCheckResult) -> bool:
	if not update.signature:
		alert("Missing signature. Cannot verify the authenticity of the release.")
		return false
	
	var hash = GDTUtils.sha256_of_file(ZIP_PATH)
	
	if not hash:
		alert("Unable to hash update file")
		return false
	
	if not verify_hash(hash, update.signature):
		alert(GDTUtils.join([
			"Downloaded file does not match the signature.",
			"This means the update is corrupted or an authorized person uploaded file.",
			"For your safety, do not try applying the update manually.",
			"",
			"Try downloading it again.",
			"If it still happens please report this ASAP!"
		]))
		
		return false
	
	return true

# Godot randomly complains about cyclic reference
# This garbage function fixes it
func alert(text: String, title := "GodotTogether") -> AcceptDialog:
	return main.get("gui").call("alert", text, title)

func apply_update() -> void:
	GDTUpdateCheckResult.clear_cache()
	
	var installer = GDTUpdateInstaller.new()
	var zip_err = installer.open_zip(ZIP_PATH)
	
	if zip_err != OK:
		alert("Unable to open update file: %s" % error_string(zip_err) + "\nPlease report this", "Error applying update")
		installer.queue_free()
		return
	
	var valid_err = installer.validate()
	
	if not valid_err.is_empty():
		alert(valid_err + "\nPlease report this.", "Update file is invalid")
		installer.queue_free()
		return
	
	installer.start()
	
	print("[GodotTogether] Shutting down plugin for update")
	main.shutdown()
