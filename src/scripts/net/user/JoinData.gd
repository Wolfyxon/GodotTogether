@tool

### Class for data sent by users upon joining 
class_name GodotTogetherJoinData

const FIELDS = [
	"username",
	"password",
	"protocol_version"
]

var username: String
var password: String
var protocol_version := GodotTogether.PROTOCOL_VERSION

func as_dict() -> Dictionary:
	var dict = {}

	for field in FIELDS:
		dict[field] = self[field]

	return dict

static func from_dict(dict: Dictionary) -> GodotTogetherJoinData:
	var res = GodotTogetherJoinData.new()

	for field in FIELDS:
		if not field in dict: continue
		res[field] = dict[field]

	return res
