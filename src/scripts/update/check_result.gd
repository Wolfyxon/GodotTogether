extends RefCounted
class_name GDTUpdateCheckResult

enum ResultType {
	Fail,
	RunningLatest,
	UpdateAvailable
}

var type: ResultType = ResultType.RunningLatest
var version: String = ""
var download_url: String = ""
var error: String = ""

func is_err() -> bool:
	return type == ResultType.Fail

static func err(message: String) -> GDTUpdateCheckResult:
	var res = GDTUpdateCheckResult.new()
	res.error = message
	res.type = ResultType.Fail
	
	if message.is_empty():
		res.error = "Unknown error"
	
	return res
	
