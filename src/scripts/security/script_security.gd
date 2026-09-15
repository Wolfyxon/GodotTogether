@tool
extends GDTComponent
class_name GDTScriptSecurity

const TOOL_ANNOTATION = "@tool"

func _ready() -> void:
	report_ready()

func sanitize_buffer(buf: PackedByteArray) -> PackedByteArray:
	var text = buf.get_string_from_utf8()
	text = detool_code(text)
	
	return text.to_utf8_buffer()

static func is_script_line_ignored(line: String) -> bool:
	var trimmed = line.strip_edges(true, false)
	
	if trimmed.is_empty():
		return true
		
	if trimmed.contains("#"):
		return true
		
	return false

static func detool_code(source: String) -> String:
	# TODO: Replace this with something more efficient. 
	# The function should iterate on the raw file buffer and
	# replace bytes instead of allocating a string
	
	var lines = source.split("\n")
	
	for line_i in lines.size():
		var line = lines[line_i]
		
		if not is_script_line_ignored(line) and not line.begins_with("@"):
			break
		
		if line.begins_with(TOOL_ANNOTATION):
			lines[line_i] = "#" + TOOL_ANNOTATION + line.erase(0, TOOL_ANNOTATION.length())
	
	return GDTUtils.join(lines, "\n")
