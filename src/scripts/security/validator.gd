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
	if GDTFiles.has_traversal(path):
		return false
	
	if not GDTFiles.is_path_in_project(path):
		return false
	
	var local_path = ProjectSettings.localize_path(path)
	
	# Double check just to be sure
	if GDTFiles.has_traversal(path):
		return false
	
	if local_path.begins_with("res://addons/"):
		return false
	
	return true

static func validate_existing_file_path(path: String) -> bool:
	if not is_path_safe(path):
		printerr("Unsafe file path: %s" % path)
		return false
	
	if not FileAccess.file_exists(path):
		printerr("File doesn't exist: %s" % path)
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
