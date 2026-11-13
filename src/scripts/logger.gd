@tool
extends Logger
class_name GDTLogger

signal got_known_error(code: KnownError)
signal error_spam_detected

enum KnownError {
	UNKNOWN,
	RPC_CHECKSUM
}

const MATCH_MAP = {
	KnownError.RPC_CHECKSUM: [
		"The rpc node checksum failed. Make sure to have the same methods"
	]
}

const FRAME_RESOLUTION = 10

var _err_mutex := Mutex.new()

var errors_last_frame: int = 0
var frame_error_history: Array = []

var was_spamming_errors: bool = false

func _init() -> void:
	GDTUtils.get_tree().process_frame.connect(_process)

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
	
	_err_mutex.lock()
	errors_last_frame += 1
	
	if err != KnownError.UNKNOWN:
		got_known_error.emit(err)
	
	_err_mutex.unlock()

func _process() -> void:
	if frame_error_history.size() >= FRAME_RESOLUTION:
		frame_error_history.pop_front()
	
	frame_error_history.append(errors_last_frame)
	errors_last_frame = 0
	
	if not was_spamming_errors and is_spamming_errors():
		was_spamming_errors = true
		error_spam_detected.emit()

func get_avg_errors_per_frame() -> float:
	return GDTUtils.avg(frame_error_history)

func is_spamming_errors() -> bool:
	if frame_error_history.size() < 2:
		return false
	
	for i in frame_error_history:
		if i == 0:
			return false
	
	return true

static func get_error_for_message(msg: String) -> KnownError:
	for err in MATCH_MAP.keys():
		for substr in MATCH_MAP[err]:
			if msg.contains(substr):
				return err
	
	return KnownError.UNKNOWN
