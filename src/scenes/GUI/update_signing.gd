@tool
extends VBoxContainer
class_name GDTReleaseSigner

var main: GodotTogether

const BUILD_PATH = "res://addons/GodotTogether/build/GodotTogether.zip"
const SIG_PATH = "res://addons/GodotTogether/build/GodotTogether.zip.gdsig"

func _on_btn_sign_pressed() -> void:
	var build_hash = GDTUtils.sha256_of_file(BUILD_PATH)
	
	if not build_hash:
		main.gui.alert("Unable to get build hash. Make sure the build zip exists")
		return
		
	var sign_buf = main.updater.sign_hash($keyInput.text, build_hash)
	
	if not sign_buf:
		main.gui.alert("Unable to sign. Make sure the key is valid")
		return
	
	var f = FileAccess.open(SIG_PATH, FileAccess.WRITE)
	
	if not f:
		main.gui.alert("Unable to create signature file")
		return
		
	if not f.store_buffer(sign_buf):
		main.gui.alert("Unable to write signature")
		return
		
	main.gui.alert("Signature created at %s" % SIG_PATH)

func _on_btn_verify_pressed() -> void:
	var build_hash = GDTUtils.sha256_of_file(BUILD_PATH)
	var signature = FileAccess.get_file_as_bytes(SIG_PATH)
	
	if not build_hash:
		main.gui.alert("Unable to get build hash. Make sure the build zip exists")
		return
	
	if not signature:
		main.gui.alert("Unable to get signature buffer. Make sure the signature exists")
		return
	
	if main.updater.verify_hash(build_hash, signature):
		main.gui.alert("OK. Signature is valid")
	else:
		main.gui.alert("ERROR: Signature is invalid")
