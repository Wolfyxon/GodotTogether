@tool

class_name GDTJoinData

const FIELDS = [
	"username",
	"password",
	"protocol_version",
	"rpc_checksum"
]

var username: String
var password: String
var protocol_version := GodotTogether.PROTOCOL_VERSION
var rpc_checksum := -1

func to_dict() -> Dictionary:
	var dict = {}

	for field in FIELDS:
		dict[field] = self[field]

	return dict

static func from_dict(dict: Dictionary) -> GDTJoinData:
	var res = GDTJoinData.new()

	for field in FIELDS:
		if not field in dict: continue
		res[field] = dict[field]

	return res
