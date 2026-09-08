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

func update_file(path: String) -> void:
	var hash = FileAccess.get_sha256(path)
	
	if hash:
		file_hashes[path] = hash
	else:
		file_hashes.erase(path)

func pause() -> void:
	scan_timer.paused = true
	
func resume() -> void:
	ignore_last_changes()
	scan_timer.paused = false

func scan_files() -> void:
	if not can_sync_files(): return
	
	var current_hashes = GDTFiles.get_file_tree_hashes()
	
	for path in current_hashes:
		# (New file) or (File changed)
		if (not path in file_hashes) or (file_hashes[path] != current_hashes[path]):
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

func _file_changed(path: String) -> void:
	if main.client.is_active():
		var buffer = FileAccess.get_file_as_bytes(path)

		if buffer:
			_c2s_request_file_write.rpc_id(1, path, buffer)

	elif main.server.is_active():
		server_broadcast_file_at_path(path)

func _file_removed(path: String) -> void:
	if main.client.is_active():
		_c2s_request_file_delete.rpc_id(1, path)

	elif main.server.is_active():
		server_broadcast_file_delete(path)

@rpc("authority", "reliable")
func write_file(path: String, buffer: PackedByteArray) -> void:
	if not GDTValidator.is_path_safe(path):
		printerr("Server tried to write at unsafe location: %s" % path)
		return
	
	GDTFiles.ensure_dir_exists(path)
	
	var current_hash = FileAccess.get_sha256(path)
	var new_hash = GDTUtils.sha256_of_buffer(buffer)
	
	if FileAccess.file_exists(path) and current_hash == new_hash:
		return
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	var err = FileAccess.get_open_error()

	assert(err == OK, "Failed to open %s: %d" % [path, err])
	
	pause()
	
	file.store_buffer(buffer)
	file.close()
	
	resume.call_deferred()
	
	if path.get_extension() == "gd":
		EditorInterface.get_script_editor().reload_open_files.call_deferred()
		
		if "@tool" in buffer.get_string_from_utf8():
			var warning_message = "Tool script detected (%s). It can execute malicious code in your editor!" % path
			print(warning_message)
	
			if main and main.get_gui():
				main.get_gui().alert(warning_message)
	else:
		EditorInterface.get_resource_filesystem().scan.call_deferred()

@rpc("authority", "reliable")
func delete_file(path: String) -> void:
	if not GDTValidator.is_path_safe(path):
		printerr("Server tried to delete file at unsafe location: %s" % path)
		return
	
	var dir = DirAccess.open("res://")
	
	if not dir:
		printerr("Unable to acces project directory for file removal")
		return
		
	var err = dir.remove(path)
	
	if err != OK:
		printerr("Error code %s removing file %s" % [err, path])
		return
	
	update_file(path)

func server_broadcast_file_write(path: String, buffer: PackedByteArray, sender := 0) -> void:
	main.server.auth_rpc(write_file, [path, buffer], [sender])

func server_broadcast_file_at_path(path: String, sender := 0) -> void:
	var buf = FileAccess.get_file_as_bytes(path)
	
	if buf:
		server_broadcast_file_write(path, buf, sender)

func server_broadcast_file_delete(path: String, sender := 0) -> void:
	main.server.auth_rpc(delete_file, [path], [sender])

@rpc("any_peer", "reliable")
func _c2s_request_file_write(path: String, buffer: PackedByteArray) -> void:
	if not main.server.is_active(): return
	
	var id = multiplayer.get_remote_sender_id()
	
	if not main.server.caller_has_permission(GodotTogether.Permission.MODIFY_CUSTOM_FILES):
		return
	
	if not GDTValidator.is_path_safe(path): 
		printerr("User %s tried to write file at unsafe location: %s" % [id, path])
		return
	
	write_file(path, buffer)
	server_broadcast_file_write(path, buffer, id)

@rpc("any_peer", "reliable")
func _c2s_request_file_delete(path: String) -> void:
	if not main.server.is_active(): return
	
	var id = multiplayer.get_remote_sender_id()
	
	if not main.server.caller_has_permission(GodotTogether.Permission.MODIFY_CUSTOM_FILES):
		return
	
	if not GDTValidator.is_path_safe(path): 
		printerr("User %s tried to delete file at unsafe location: %s" % [id, path])
		return
	
	delete_file(path)
	server_broadcast_file_delete(path, id)
