extends Object
class_name GodotTogetherValidator

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

static func is_empty(string: String):
	return string.replace(" ", "").is_empty()

static func is_path_safe(path: String):
	return GodotTogetherFiles.is_path_in_project(path) and not path.contains("..")

static func validate_version(target_version: int):
	if target_version > GodotTogether.protocol_version: return VersionError.UPDATE_REQUIRED
	if target_version < GodotTogether.protocol_version: return VersionError.TARGET_TOO_OLD
	
	return VersionError.OK

static func validate_username(username: String) -> TextError:
	if username.length() > max_username_length: return TextError.TOO_LONG
	if is_empty(username): return TextError.EMPTY
	
	return TextError.OK

static func validate_message(message: String) -> TextError:
	if message.length() > max_message_length: return TextError.TOO_LONG
	if is_empty(message): return TextError.EMPTY
	
	return TextError.OK
