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

func is_err() -> bool:
	return type == ResultType.Fail

func save_to_settings() -> void:
	if not type in [ResultType.RunningLatest, ResultType.UpdateAvailable]:
		printerr("Cannot store invalid check result %s" % type)
		return
	
	GDTSettings.set_setting("update/latest_version", version)
	GDTSettings.set_setting("update/download_url", download_url)

static func clear_cache() -> void:
	GDTSettings.set_setting("update/latest_version", null)
	GDTSettings.set_setting("update/download_url", null)

static func get_from_settings() -> GDTUpdateCheckResult:
	var ver = GDTSettings.get_setting("update/latest_version")
	var url  = GDTSettings.get_setting("update/download_url")
	
	if not ver or not url:
		return
	
	var res = GDTUpdateCheckResult.new()
	res.type = ResultType.UnknownState
	res.version = ver
	res.download_url = url
	
	return res

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
