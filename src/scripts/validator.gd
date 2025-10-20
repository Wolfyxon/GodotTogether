@tool
extends Object
class_name GDTValidator

const max_username_length = 32
const max_message_length = 1024

enum TextError {
	OK,
	TOO_LONG,
	TOO_SHORT,
	EMPTY,
}

enum VersionError {
	OK,
	UPDATE_REQUIRED,
	TARGET_TOO_OLD,
}

static func is_empty(string: String) -> bool:
	return string.replace(" ", "").is_empty()

static func is_path_safe(path: String) -> bool:
	if not GDTFiles.is_path_in_project(path):
		return false
	
	if path.contains(".."):
		return false
	
	var local_path = ProjectSettings.localize_path(path)
	
	if local_path.begins_with("res://addons/"):
		print("unsafe")
		return false
	
	return true
	
static func validate_username(username: String) -> TextError:
	if username.length() > max_username_length: return TextError.TOO_LONG
	if is_empty(username): return TextError.EMPTY
	
	return TextError.OK

static func validate_message(message: String) -> TextError:
	if message.length() > max_message_length: return TextError.TOO_LONG
	if is_empty(message): return TextError.EMPTY
	
	return TextError.OK
