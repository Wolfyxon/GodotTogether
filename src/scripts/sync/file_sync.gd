@tool
extends GDTComponent
class_name GDTFileSync

signal scan_started
signal scan_complete

const CHUNK_SIZE = 1024 * 1024 * 24 # 24 kB

var scan_timer = Timer.new()
var file_mod_times := {}

func _ready() -> void:
	update_timer_wait_times()
	main.get_settings().settings_changed.connect(update_timer_wait_times)
	
	scan_timer.timeout.connect(scan_files)
	add_child(scan_timer)
	scan_timer.start()
	
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(scan_files)
	
	ignore_last_changes()
	report_ready()

func update_timer_wait_times() -> void:
	scan_timer.wait_time = main.get_settings().get_setting("sync/file_refresh_rate")

func ignore_last_changes() -> void:
	file_mod_times = GDTFiles.get_file_modification_times()

func update_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		file_mod_times.erase(path)
		return
	
	file_mod_times[path] = FileAccess.get_modified_time(path)

func pause() -> void:
	scan_timer.paused = true
	
func resume() -> void:
	ignore_last_changes()
	scan_timer.paused = false

func scan_files() -> void:
	if not can_sync_files(): return
	
	scan_started.emit()
	
	var new_times = GDTFiles.get_file_modification_times()
	
	for path in new_times:
		# (New file) or (File changed)
		if (not path in file_mod_times) or (file_mod_times[path] < new_times[path]):
			_file_changed(path)
	
	for path in file_mod_times:
		if not path in new_times:
			_file_removed(path)
	
	file_mod_times = new_times
	scan_complete.emit()

func can_sync_files() -> bool:
	return (
		main != null and
		main.is_session_active() and
		not scan_timer.paused and 
		not (main.client.is_active() and not main.client.is_fully_synced) and
		not main.get_settings().get_setting("dev/disable_real_time_file_sync")
	)

func _file_changed(path: String) -> void:
	if main.client.is_active():
		client_send_file_to_server(path)
	
	elif main.server.is_active():
		server_broadcast_file_at_path(path)

func _file_removed(path: String) -> void:
	if main.client.is_active():
		_c2s_request_file_delete.rpc_id(1, path)

	elif main.server.is_active():
		server_broadcast_file_delete(path)

static func read_chunks_callback(path: String, fn: Callable, chunk_size := CHUNK_SIZE) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	
	if not file:
		GDTUtils.printerr_stack(
			"Unable to open file: '%s': %s" % 
			[path, error_string(FileAccess.get_open_error())]
		)
		return
	
	var current_pos = 0
	
	while true:
		var buf = file.get_buffer(chunk_size)
		var size = buf.size()
		
		if size <= 0:
			break
		
		fn.call(buf, current_pos)
		current_pos += size
	
	file.close()

@rpc("authority", "reliable")
func write_file(
	path: String, 
	buffer: PackedByteArray,
	offset: int = 0,
	truncate := true
) -> void:
	if buffer.size() > CHUNK_SIZE:
		GDTUtils.printerr_stack("Buffer is greater than chunk size. This will cause problems")
	
	if offset < 0:
		GDTUtils.printerr_stack("File offset cannot be negative")
		return
	
	if offset != 0 and truncate:
		GDTUtils.printerr_stack(
			"Offset only supported with truncate off. Offset: %s Truncate: %s Path: %s" %
			[offset, truncate, path]
		)
		
		return
	
	if not GDTValidator.is_path_safe(path):
		printerr("Server tried to write at unsafe location: %s" % path)
		return
	
	GDTFiles.ensure_dir_exists(path)
	
	if path.get_extension() == "gd":
		if offset != 0:
			# TODO: Scan the complete buffer BEFORE RELEASE! SCRIPTS DO GET THIS BIG!
			GDTUtils.printerr_stack("Chunking scripts is not supported")
			return
		
		buffer = main.script_security.sanitize_buffer(buffer)
	
	var mode = FileAccess.WRITE
	
	if not truncate:
		mode = FileAccess.READ_WRITE
	
	var file = FileAccess.open(path, mode)
	var err = FileAccess.get_open_error()

	if err != OK:
		GDTUtils.printerr_stack(
			"Failed to open %s: %s\nOffset: %s Truncate: %s" % 
			[path, error_string(err), offset, truncate]
		)
		return
	
	if offset != 0:
		var file_len = file.get_length()
		
		if file_len < offset:
			GDTUtils.printerr_stack("Offset (%s) greater than file length (%s): %s" % [offset, file_len, path])
			file.close()
			return
		
		file.seek(offset)
	
	pause()
	
	file.store_buffer(buffer)
	file.close()
	
	resume.call_deferred()
	
	if path.get_extension() == "gd":
		EditorInterface.get_script_editor().reload_open_files.call_deferred()
		main.script_security.check_for_tool_script(path, buffer)
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

func server_broadcast_file_write(
	path: String, 
	buffer: PackedByteArray, 
	offset: int = 0,
	truncate := true,
	sender := 0
) -> void:
	main.server.auth_rpc(write_file, [path, buffer, offset, truncate], [sender])

func server_broadcast_file_at_path(path: String, sender := 0) -> void:
	read_chunks_callback(path, func(buf: PackedByteArray, i: int):
		server_broadcast_file_write(
			path, 
			buf, 
			i,
			i == 0,
			sender
		)
	)

func server_broadcast_file_delete(path: String, sender := 0) -> void:
	main.server.auth_rpc(delete_file, [path], [sender])

func client_send_file_to_server(path: String) -> void:
	read_chunks_callback(path, func(buf: PackedByteArray, i: int):
		_c2s_request_file_write.rpc_id(
			1, 
			path, 
			buf, 
			i, 
			i == 0
		)
	)

@rpc("any_peer", "reliable")
func _c2s_request_file_write(
	path: String, 
	buffer: PackedByteArray, 
	offset: int = 0,
	truncate := true
) -> void:
	if not main.server.is_active(): return
	
	var id = multiplayer.get_remote_sender_id()
	
	if not main.server.caller_has_permission(GodotTogether.Permission.MODIFY_CUSTOM_FILES):
		return
	
	if not GDTValidator.is_path_safe(path): 
		printerr("User %s tried to write file at unsafe location: %s" % [id, path])
		return
	
	write_file(path, buffer, offset, true)
	server_broadcast_file_write(path, buffer, offset, truncate, id)

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
