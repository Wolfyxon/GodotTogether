@abstract
extends RefCounted
class_name GDTEncodableData

@abstract
func get_encodable_fields() -> Array

func to_dict() -> Dictionary:
	var fields = get_encodable_fields()
	var dict = {}

	for field in fields:
		dict[field] = self[field]
	
	return dict

func apply_dict(dict: Dictionary) -> bool:
	var fields = get_encodable_fields()
	
	for field in fields:
		if not field in dict: 
			continue
		
		self[field] = dict[field]
	
	return true
