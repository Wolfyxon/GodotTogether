@tool
extends Logger
class_name GDTLogger

signal got_known_error(code: KnownError)

enum KnownError {
	UNKNOWN,
	RPC_CHECKSUM
}

const MATCH_MAP = {
	KnownError.RPC_CHECKSUM: [
		"The rpc node checksum failed. Make sure to have the same methods"
	]
}

var _err_mutex := Mutex.new()

func attach() -> void:
	OS.add_logger(self)

func detach() -> void:
	OS.remove_logger(self)

func _log_error(
	_function: String, 
	_file: String, 
	_line: int, 
	code: String, 
	_rationale: String, 
	_editor_notify: bool, 
	_error_type: int, 
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	var err = get_error_for_message(code)
	
	if err == KnownError.UNKNOWN:
		return
		
	_err_mutex.lock()
	
	got_known_error.emit(err)
	
	_err_mutex.unlock()

static func get_error_for_message(msg: String) -> KnownError:
	for err in MATCH_MAP.keys():
		for substr in MATCH_MAP[err]:
			if msg.contains(substr):
				return err
	
	return KnownError.UNKNOWN
