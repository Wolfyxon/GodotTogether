@tool
extends VBoxContainer
class_name GDTDevMenuSync

const MAX_TIME_RESOLUTION = 64

@onready var check: CheckBox = $enabled

var main: GodotTogether = null
var first_run = true

var node_scan_durations = []
var file_scan_durations = []

var _last_node_scan_time = 0
var _last_file_scan_time = 0

func _process(delta: float) -> void:
	if not main: return
	if not check.button_pressed: return
	
	$nodeCount.text = "Total nodes: %s" % main.node_sync.node_data_dict.size()
	$nodeTime.text = "Avg node scan time: %s s" % GDTUtils.avg(node_scan_durations)
	$nodeCanSync.text = "Is allowed to run: %s" % main.node_sync.can_sync_nodes()
	
	$fileCount.text = "Total files: %s" % main.file_sync.file_mod_times.size()
	$fileTime.text = "Avg file scan time: %s s" % GDTUtils.avg(file_scan_durations)
	$fileCanSync.text = "Is allowed to run: %s" % main.file_sync.can_sync_files()
	$filesInitSynced.text = "Files initially synced: %s" % main.client.is_fully_synced

func setup() -> void:
	if not main:
		printerr("Profiler setup failed because main is null") 
		return
	
	main.node_sync.scan_started.connect(_node_scan_started)
	main.node_sync.scan_complete.connect(_node_scan_complete)
	
	main.file_sync.scan_started.connect(_file_scan_started)
	main.file_sync.scan_complete.connect(_file_scan_complete)

func _node_scan_started() -> void:
	_last_node_scan_time = Time.get_unix_time_from_system()

func _node_scan_complete() -> void:
	if _last_node_scan_time == 0: 
		return
	
	var now = Time.get_unix_time_from_system()
	node_scan_durations.append(now - _last_node_scan_time)
	
	if node_scan_durations.size() > MAX_TIME_RESOLUTION:
		node_scan_durations.pop_front()

func _file_scan_started() -> void:
	_last_file_scan_time = Time.get_unix_time_from_system()

func  _file_scan_complete() -> void:
	if _last_file_scan_time == 0:
		return
		
	var now = Time.get_unix_time_from_system()
	file_scan_durations.append(now - _last_file_scan_time)
	
	if file_scan_durations.size() > MAX_TIME_RESOLUTION:
		file_scan_durations.pop_front()

func _on_enabled_pressed() -> void:
	if first_run:
		setup()
		first_run = false


func _on_btn_files_pressed() -> void:
	var dict = main.file_sync.file_mod_times
	
	for path in dict.keys():
		prints(path, dict[path])
