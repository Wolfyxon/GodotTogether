extends Object
class_name GodotTogetherValidator

const max_username_length = 32

enum TextError {
	OK,
	TOO_LONG,
	EMPTY,
}

enum VersionError {
	OK,
	UPDATE_REQUIRED,
	TARGET_TOO_OLD,
}

static func validate_version(target_version:int):
	if target_version > GodotTogether.compatibility_version: return VersionError.UPDATE_REQUIRED
	if target_version < GodotTogether.compatibility_version: return VersionError.TARGET_TOO_OLD
	
	return VersionError.OK

static func validate_username(username:String) -> TextError:
	if username.length() > max_username_length: return TextError.TOO_LONG
	if username.replace(" ","").length() == 0: return TextError.EMPTY
	
	return TextError.OK
