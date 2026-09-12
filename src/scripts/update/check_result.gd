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

func save_to_settings() -> void:
	if not type in [ResultType.RunningLatest, ResultType.UpdateAvailable]:
		printerr("Cannot store invalid check result %s" % type)
		return
	
	var sig64 = Marshalls.raw_to_base64(signature_buf)
	
	GDTSettings.set_setting("update/latest_version", version)
	GDTSettings.set_setting("update/download_url", download_url)
	GDTSettings.set_setting("update/download_signature", sig64)

func get_signature(i: int = 0) -> PackedByteArray:
	var start = i * GDTUpdater.SIGNATURE_LENGTH
	var end = start + GDTUpdater.SIGNATURE_LENGTH
	
	return signature_buf.slice(start, end)

func get_signature_count() -> int:
	@warning_ignore("integer_division")
	return int(signature_buf.size() / GDTUpdater.SIGNATURE_LENGTH)

func has_signature() -> bool:
	return signature_buf and not signature_buf.is_empty()

static func clear_cache() -> void:
	GDTSettings.set_setting("update/latest_version", null)
	GDTSettings.set_setting("update/download_url", null)
	GDTSettings.set_setting("update/download_signature", null)

static func get_from_settings() -> GDTUpdateCheckResult:
	var ver = GDTSettings.get_setting("update/latest_version")
	var url  = GDTSettings.get_setting("update/download_url")
	var sig_text = GDTSettings.get_setting("update/download_signature")
	
	if not ver or not url:
		return
	
	if sig_text:
		sig_text = sig_text.remove_chars("\t\n\"',. ")
	else:
		sig_text = ""
	
	var res = GDTUpdateCheckResult.new()
	res.type = ResultType.UnknownState
	res.version = ver
	res.download_url = url
	res.signature_buf = Marshalls.base64_to_raw(sig_text)
	
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
