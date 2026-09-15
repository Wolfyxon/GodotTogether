extends RefCounted
class_name GDTSecurityThreat

enum Type {
	TOOL_SCRIPT
}

var file_path := ""

static func new_script_threat(type: Type, _file_path: String, line: int) -> GDTSecurityThreat:
	var res = GDTSecurityThreat.new()
	
	return res
