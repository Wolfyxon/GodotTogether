@tool
extends GDTComponent
class_name GDTScriptSecurity

const TOOL_ANNOTATION = "@tool"

static func detool_code(source: String) -> String:
	# TODO: Replace this with something more efficient. 
	# The function should iterate on the raw file buffer and
	# replace bytes instead of allocating a string
	
	var lines = source.split("\n")
	
	for line_i in lines.size():
		var line = lines[line_i]
		
		if not line.strip_edges().is_empty() and not line.begins_with("@"):
			break
		
		if line.begins_with(TOOL_ANNOTATION):
			lines[line_i] = "#" + TOOL_ANNOTATION + line.erase(TOOL_ANNOTATION.length())
	
	return GDTUtils.join(lines, "\n")
