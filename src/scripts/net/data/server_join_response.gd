@tool
extends GDTEncodableData
class_name GDTServerJoinResponse

# IMPORTANT: This data must be sent only after a user is authenticated

func get_encodable_fields() -> Array:
	return [
		
	]

static func from_dict(dict: Dictionary) -> GDTServerJoinResponse:
	var res = GDTServerJoinResponse.new()
	
	if not res.apply_dict(dict):
		return
	
	return res
