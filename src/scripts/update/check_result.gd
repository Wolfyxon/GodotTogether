extends RefCounted
class_name GDTUpdateCheckResult

enum ResultType {
	Fail,
	UnknownState,
	RunningLatest,
	UpdateAvailable
}

var type: ResultType = ResultType.RunningLatest
var version: String = ""
var download_url: String = ""
var error: String = ""
var signature_buf: PackedByteArray = []

func is_err() -> bool:
	return type == ResultType.Fail

func get_signature(i: int = 0) -> PackedByteArray:
	var start = i * GDTUpdater.SIGNATURE_LENGTH
	var end = start + GDTUpdater.SIGNATURE_LENGTH
	
	return signature_buf.slice(start, end)

func get_signature_count() -> int:
	@warning_ignore("integer_division")
	return int(signature_buf.size() / GDTUpdater.SIGNATURE_LENGTH)

func has_signature() -> bool:
	return signature_buf and not signature_buf.is_empty()

static func err(message: String) -> GDTUpdateCheckResult:
	var res = GDTUpdateCheckResult.new()
	res.error = message
	res.type = ResultType.Fail
	
	if message.is_empty():
		res.error = "Unknown error"
	
	return res
	
static func status_latest() -> GDTUpdateCheckResult:
	var res = GDTUpdateCheckResult.new()
	res.type = ResultType.RunningLatest
	return res
