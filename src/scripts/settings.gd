@tool
extends GDTComponent
class_name GDTSettings

signal settings_changed

const FILE_PATH = "res://addons/GodotTogether/settings.json"

const _DEFAULT_DATA = {
	"username": "Cool person",
	"format_version": 1,
	
	"last_connection": {
		"ip": "",
		"port": 5017,
	},
	
	"server": {
		"password": "",
		"port": 5017,
		"max_users": 10,
		"whitelist": ["127.0.0.1", "0.0.0.0", "0:0:0:0:0:0:0:1"],
		"blacklist": [],
		"whitelist_enabled": false,
		"allow_external_connections": true,
		"require_approval": false
	},
	"sync": {
		"node_refresh_rate": 0.1,
		"file_refresh_rate": 1,
	},
	"update": {
		"latest_version": null,
		"download_url": null,
		"download_signature": null,
		"last_check": 0,
		"check_interval_hours": 168, # weekly
		"auto_check_enabled": true
	},
	"security": {
		"sanitize_tool_scripts": true
	},
	"dev": {
		# Everything here should be false by default
		"menu_button": false,
		"run_tests_on_start": false,
		"disable_real_time_file_sync": false,
		"disable_real_time_node_sync": false,
		"restart_broadcast": false
	},
	"notifications": {
		"users": true
	},
	
	"seen" : {
		"disclaimer": false
	}
}

var data := {}
var is_unsaved := false
var have_changed := false
var error_message := ""
var error_line := 0

var save_mutex = Mutex.new()

func _ready() -> void:
	load_settings()
	
	if GDTUtils.has_readonly(data):
		component_error("Data dict contains read-only values")
		return
	
	var save_timer = Timer.new()
	save_timer.timeout.connect(_periodic_save)
	save_timer.wait_time = 1
	add_child(save_timer)
	save_timer.start()
	
	report_ready()

func _component_init() -> void:
	load_default()

func _periodic_save() -> void:
	if not have_changed: return
	if not is_unsaved: return
	
	save_settings()

func has_error() -> bool:
	return not error_message.is_empty()

func load_default() -> void:
	data = get_default_data()
	settings_changed.emit()

func save_settings() -> void:
	save_mutex.lock()
	
	var f = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	
	if not f:
		var err_str = error_string(FileAccess.get_open_error())
		GDTUtils.printerr_stack("Unable to open settings file for saving: %s" % err_str)
		return
	
	f.store_string(JSON.stringify(data,"	"))
	is_unsaved = false
	
	save_mutex.unlock()

func load_settings() -> bool:
	error_message = ""
	error_line = 0
	
	if not settings_exist():
		load_default()
		return true
	
	var f = FileAccess.open(FILE_PATH, FileAccess.READ)
	
	if not f:
		var err_str = error_string(FileAccess.get_open_error())
		GDTUtils.printerr_stack("Unable to open settings file for reading: %s" % err_str)
		return false
	
	var json = JSON.new()
	var err = json.parse(f.get_as_text(), true)
	
	if err != OK:
		GDTUtils.printerr_stack("Parsing settings failed, loading default data")
		error_message = json.get_error_message()
		error_line = json.get_error_line()
		load_default()
		return false
	
	var parsed = json.data
	
	if typeof(parsed) == TYPE_ARRAY:
		error_message = "Data is not a dictionary, but an array"
		load_default()
		return false
	
	var merged = GDTUtils.merge(parsed.duplicate(true), get_default_data())
	data = merged.duplicate(true)
	
	settings_changed.emit()
	return true

func reset_settings() -> void:
	load_default()
	save_settings()

func store_update_cache(update: GDTUpdateCheckResult) -> void:
	const ALLOWED_TYPES = [
		GDTUpdateCheckResult.ResultType.RunningLatest, 
		GDTUpdateCheckResult.ResultType.UpdateAvailable
	]
	
	if not update.type in ALLOWED_TYPES:
		GDTUtils.printerr_stack("Cannot store invalid check result %s" % update.type)
		return
	
	var sig64 = Marshalls.raw_to_base64(update.signature_buf)
	
	set_setting("update/latest_version", update.version)
	set_setting("update/download_url", update.download_url)
	set_setting("update/download_signature", sig64)

func reset_setting(path: String) -> void:
	var default_val = GDTUtils.get_nested(get_default_data(), path)
	set_setting(path, default_val)

func clear_update_cache() -> void:
	reset_setting("update/")

func get_update_cache() -> GDTUpdateCheckResult:
	var ver = get_setting("update/latest_version")
	var url = get_setting("update/download_url")
	var sig_text = get_setting("update/download_signature")
	
	if not ver or not url:
		return
	
	if sig_text:
		sig_text = sig_text.remove_chars("\t\n\ufffd\"',. ")
	else:
		sig_text = ""
	
	var res = GDTUpdateCheckResult.new()
	res.type = GDTUpdateCheckResult.ResultType.UnknownState
	res.version = ver
	res.download_url = url
	res.signature_buf = Marshalls.base64_to_raw(sig_text)
	
	return res

func get_setting(path: String):
	return GDTUtils.get_nested(data, path)

func set_setting(path: String, value) -> void:
	is_unsaved = true
	have_changed = true
	
	GDTUtils.set_nested(data, path, value)
	settings_changed.emit()

func _set_setting_reverse(value, path: String) -> void:
	set_setting(path, value)

func make_setting_control(
	node: Control, 
	path: String, 
	format := "", 
	callback: Callable = _none
) -> void:
	var sig = null
	
	if node is OptionButton:
		node.item_selected.connect(func(idx):
			var id = node.get_item_id(idx)
			set_setting(path, id)
		)
		sig = node.item_selected
	
	elif node is Button:
		if not node.toggle_mode:
			push_error("Button %s must have toggle_mode enabled" % node.name)
		
		node.toggled.connect(_set_setting_reverse.bind(path))
		sig = node.toggled
	elif node is SpinBox:
		node.value_changed.connect(_set_setting_reverse.bind(path))
		sig = node.value_changed
	elif node is LineEdit:
		node.text_changed.connect(_set_setting_reverse.bind(path))
		sig = node.text_changed
	elif node is Label:
		pass
	else:
		GDTUtils.printerr_stack("Unsupported control %s %s" % [node.get_class() ,node])
	
	update_control(node, path, format)
	settings_changed.emit(update_control.bind(node, path, format))
	
	if sig:
		sig.connect(func(_a = null, _b = null, _c = null, _d = null):
			callback.call()
		)

func update_control(node: Control, path: String, format := "") -> void:
	var value = get_setting(path)
	GDTUtils.set_control_value(node, value, format)

static func get_absolute_path() -> String:
	return ProjectSettings.globalize_path(FILE_PATH)

static func settings_exist() -> bool:
	return FileAccess.file_exists(FILE_PATH)

static func get_default_data() -> Dictionary:
	return _DEFAULT_DATA.duplicate(true)

static func _none() -> void:
	pass
