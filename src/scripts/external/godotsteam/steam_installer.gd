@tool
class_name GDTSteamInstaller
extends Node

# The asset store doesn't provide a proper API to get latest version
# Hardcoding seems the safest for now
const DOWNLOAD_URL = "https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/download/8276/"
const DOWNLOAD_SHA256 = "d4358888959a03f4df0c71aafbcdca8f34b8cb9d4522aa5c8454f0e9e3debbf7"
const DOWNLOAD_FILE = "godotsteam.zip"
const DOWNLOAD_PATH = GDTUpdater.ROOT + "/" + GDTUpdater.DOWNLOAD_DIR + "/" + DOWNLOAD_FILE
const DOWNLOAD_TIMEOUT = 30 * 60

const ADDON_DIR_NAME = "godotsteam"

var main: GodotTogether = null
var http = HTTPRequest.new()
var zip = ZIPReader.new()

var downalod_id = 0

func _ready() -> void:
	add_child(http)

func install() -> void:
	var gui = main.get_gui()
	
	var download_err = await download()
	
	if download_err == "Cancelled":
		return
	
	if download_err:
		gui.alert(download_err, "Failed to download Steam addon")
		return
		
	await install_existing()

func install_existing() -> void:
	var gui = main.get_gui()
	
	var verify_err = verify_download()
	
	if verify_err:
		gui.alert(verify_err, "Downloaded file is invalid")
		return
		
	var unzip_err = await unzip()
	
	if unzip_err:
		gui.alert(unzip_err, "Unpacking failed")
		return
	
	gui.alert("Steam addon installed successfully. \nRestart Godot if you encounter issues.")

func download() -> String:
	var dir_err = GDTUpdater.prepare_dir()
	
	if dir_err:
		return dir_err
		
	delete_download()
	
	http.timeout = DOWNLOAD_TIMEOUT
	http.download_file = DOWNLOAD_PATH
	
	var prog = main.get_gui().progress("Downloading")
	prog.bind_to_http_download(http)
	
	var init_err = http.request(DOWNLOAD_URL, ["User-Agent: %s" % GDTUpdater.USER_AGENT])
	
	print("Downloading %s into %s" % [DOWNLOAD_URL, DOWNLOAD_PATH])
	
	if init_err != OK:
		prog.queue_free()
		return "Failed to start request: %s" % error_string(init_err)
	
	var current_id = downalod_id + 1
	downalod_id = current_id
	
	var res = await http.request_completed
	var code = res[1]
	
	if prog:
		prog.queue_free()
	
	if downalod_id != current_id:
		return "Cancelled"
	
	if code == 0:
		return "No internet connection"
	
	if code == 500:
		return "Godot AssetStore is having a server-side issue"
	
	if code != 200:
		return "HTTP code %s" % code
	
	return ""

func delete_download() -> void:
	var path = GDTUpdater.ROOT + "/" + GDTUpdater.DOWNLOAD_DIR 
	
	var dir = DirAccess.open(path)
	
	if not dir:
		return
		
	if not dir.file_exists(DOWNLOAD_FILE):
		return
		
	dir.remove(DOWNLOAD_FILE)

func verify_download() -> String:
	if not FileAccess.file_exists(DOWNLOAD_PATH):
		return "Download file not found"
	
	var sum = FileAccess.get_sha256(DOWNLOAD_PATH)
	
	if sum != DOWNLOAD_SHA256:
		printerr("Download SHA256 mismatch. \nExpected: %s\nGot: %s" % [DOWNLOAD_SHA256, sum])
		return "Downloaded file is different than expected."
	
	var zip_err = zip.open(DOWNLOAD_PATH)
	
	if zip_err != OK:
		printerr("ZIP error: %s" % error_string(zip_err))
		return "Invalid ZIP file"
	
	var files = zip.get_files()
	
	if not files:
		zip.close()
		return "ZIP is empty"
	
	if not "addons/" + ADDON_DIR_NAME + "/" in files:
		zip.close()
		return "Addon not found in the ZIP"
	
	return ""

func unzip() -> String:
	var files = zip.get_files()
	
	if not files:
		return "ZIP is empty"
	
	var tree = get_tree()
	
	if not tree:
		return "No scene tree"
	
	var prog = main.gui.progress("Unpacking...")
	
	prog.set_max(0)
	for file_path in files:
		if file_path.ends_with("/"):
			continue
			
		prog.set_max(prog.get_max() + 1)
	
	for i in files.size():
		var file_path = files[i]
		
		if file_path.ends_with("/"): # Current entry is a directory
			continue
		
		var buf = zip.read_file(file_path)
		
		var physical_path = "res://" + file_path
		
		GDTUpdateInstaller.ensure_dir_exists(physical_path)
		
		var file = FileAccess.open(physical_path, FileAccess.WRITE)
		
		if not file:
			prog.queue_free()
			return "Unable to create file %s" % physical_path
		
		if not file.store_buffer(buf):
			prog.queue_free()
			return "Unable to write file: %s" % physical_path
		
		prog.add_value(1)
		print(file_path)
		
		if i % 128:
			await tree.process_frame
	
	prog.queue_free()
	
	return ""

static func addon_exists() -> bool:
	return DirAccess.open("res://addons/" + ADDON_DIR_NAME) != null
