@tool
extends GDTEncodableData
class_name GDTJoinData

var username: String
var password: String
var engine_version: String = ""
var protocol_version := GodotTogether.PROTOCOL_VERSION
var rpc_checksum := -1

func _init() -> void:
	engine_version = GDTUtils.get_engine_version_str()

func get_encodable_fields() -> Array:
	return [
		"username",
		"password",
		"engine_version",
		"protocol_version",
		"rpc_checksum"
	]

static func from_dict(dict: Dictionary) -> GDTJoinData:
	var res = GDTJoinData.new()
	
	if not res.apply_dict(dict):
		return
	
	return res
