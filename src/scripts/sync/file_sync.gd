extends GDTComponent
class_name GDTFileSync

var filesystem_watcher: Timer = Timer.new()
var file_hashes := {}

var scan_timer = Timer.new()

func _ready() -> void:
	scan_timer.wait_time = 1.0
	scan_timer.timeout.connect(scan_files)
	add_child(scan_timer)
	scan_timer.start()
	
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(scan_files)
	
	ignore_last_changes()
	report_ready()

func ignore_last_changes() -> void:
	file_hashes = GDTFiles.get_file_tree_hashes()

func update_file(path: String, hash: String) -> void:
	file_hashes[path] = FileAccess.get_sha256(path)

func pause() -> void:
	scan_timer.paused = true
	
func resume() -> void:
	ignore_last_changes()
	scan_timer.paused = false

func scan_files() -> void:
	if not can_sync_files(): return
	
	var current_hashes = GDTFiles.get_file_tree_hashes()
	
	for path in current_hashes:
		if not path in file_hashes:
			_file_added(path)
		elif file_hashes[path] != current_hashes[path]:
			_file_changed(path)

	for path in file_hashes:
		if not path in current_hashes:
			_file_removed(path)
			
	file_hashes = current_hashes

func can_sync_files() -> bool:
	return (
		main != null and
		main.is_session_active() and
		not scan_timer.paused and 
		not (main.client.is_active() and not main.client.is_fully_synced) and
		not GDTSettings.get_setting("dev/disable_real_time_file_sync")
	)

func write_file(path: String, buffer: PackedByteArray) -> void:
	if not GDTValidator.is_path_safe(path):
		return
	
	GDTFiles.ensure_dir_exists(path)
	
	var current_hash = FileAccess.get_sha256(path)
	var new_hash = GDTUtils.sha256_of_buffer(buffer)
	
	if FileAccess.file_exists(path) and current_hash == new_hash:
		return
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	var err = FileAccess.get_open_error()

	assert(err == OK, "Failed to open %s: %d" % [path, err])
	
	file.store_buffer(buffer)
	file.close()
	
	if path.get_extension() == "gd":
		EditorInterface.get_script_editor().reload_open_files.call_deferred()
		
		if "@tool" in buffer.get_string_from_utf8():
			var warning_message = "Tool script detected (%s). It can execute malicious code in your editor!" % path
			print(warning_message)
	
			if main and main.get_gui():
				main.get_gui().alert(warning_message)
	else:
		EditorInterface.get_resource_filesystem().scan.call_deferred()

func _file_added(path: String) -> void:
	if main.client.is_active():
		var buffer = FileAccess.get_file_as_bytes(path)
		
		if buffer:
			print("[CLIENT] Sending file add: ", path)
			main.server.receive_file_from_client.rpc_id(1, path, buffer)
	
	elif main.server.is_active():
		print("[SERVER] Broadcasting file add: ", path)
		main.server.broadcast_file_at_path(path)

func _file_changed(path: String) -> void:
	if main.client.is_active():
		var buffer = FileAccess.get_file_as_bytes(path)

		if buffer:
			print("[CLIENT] Sending file modify: ", path)
			main.server.receive_file_from_client.rpc_id(1, path, buffer)

	elif main.server.is_active():
		print("[SERVER] Broadcasting file modify: ", path)
		main.server.broadcast_file_at_path(path)

func _file_removed(path: String) -> void:
	if main.client.is_active():
		print("[CLIENT] Sending file remove: ", path)
		main.server.file_remove_from_client.rpc_id(1, path)

	elif main.server.is_active():
		print("[SERVER] Broadcasting file remove: ", path)
		main.server.broadcast_file_remove(path)
