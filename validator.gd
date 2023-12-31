extends Object
class_name GodotTogetherValidator

const max_username_length = 32

enum UsernameError {
	OK,
	TOO_LONG,
	EMPTY,
}

static func validate_username(username:String) -> UsernameError:
	if username.length() > max_username_length: return UsernameError.TOO_LONG
	if username.replace(" ","").length() == 0: return UsernameError.EMPTY
	
	return UsernameError.OK
