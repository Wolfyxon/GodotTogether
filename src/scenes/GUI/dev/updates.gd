@tool
extends VBoxContainer

var main: GodotTogether = null

const BUILD_PATH = "res://addons/GodotTogether/build/GodotTogether.zip"
const SIG_PATH = "res://addons/GodotTogether/build/release.gdsig"

func _on_visibility_changed() -> void:
	if not main: return
	
	load_check_data()

func load_check_data() -> void:
	var res = main.updater.latest_result
	if not res: return
	
	var status_str = GDTUpdateCheckResult.ResultType.keys()[res.type]
	$checkStatus.text = "Check status: %s" % status_str
	$error.text = "Error: %s" % res.error
	
	var last_check = main.updater.get_last_check_time()
	var last_check_str = "never"
	
	if last_check > 0:
		last_check_str = Time.get_datetime_string_from_unix_time(last_check)
	
	$lastCheck.text = "Last check time: %s" % last_check_str
	$latestVersion.text = "Latest version: %s" % res.version
	$url/value.text = res.download_url

func _on_btn_sign_pressed() -> void:
	var build_hash = FileAccess.get_sha256(BUILD_PATH)
	
	if not build_hash:
		main.get_gui().alert("Unable to get build hash. Make sure the build zip exists")
		return
		
	var sign_buf = main.updater.sign_hash($keyInput.text, build_hash)
	
	if not sign_buf:
		main.get_gui().alert("Unable to sign. Make sure the key is valid")
		return
	
	if not main.updater.verify_hash(build_hash, sign_buf):
		main.get_gui().alert("Created signature doesn't match public key. Make sure you used the maching private key")
		return
	
	var f = FileAccess.open(SIG_PATH, FileAccess.WRITE)
	
	if not f:
		main.get_gui().alert("Unable to create signature file")
		return
		
	if not f.store_buffer(sign_buf):
		main.get_gui().alert("Unable to write signature")
		return
		
	main.get_gui().alert("Signature created and verified at %s" % SIG_PATH)

func _on_btn_verify_pressed() -> void:
	var build_hash = FileAccess.get_sha256(BUILD_PATH)
	var signature = FileAccess.get_file_as_bytes(SIG_PATH)
	
	if not build_hash:
		main.get_gui().alert("Unable to get build hash. Make sure the build zip exists")
		return
	
	if not signature:
		main.get_gui().alert("Unable to get signature buffer. Make sure the signature exists")
		return
	
	if main.updater.verify_hash(build_hash, signature):
		main.get_gui().alert("OK. Signature is valid")
	else:
		main.get_gui().alert("ERROR: Signature is invalid")


func _on_btn_clear_update_data_pressed() -> void:
	main.get_settings().clear_update_cache()
	load_check_data()
