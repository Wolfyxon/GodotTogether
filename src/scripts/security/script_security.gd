@tool
extends GDTComponent
class_name GDTScriptSecurity

const TOOL_ANNOTATION = "@tool"

func _ready() -> void:
	report_ready()

func check_for_tool_script(path: String, buffer: PackedByteArray) -> void:
	# Script is sanitized. No need for warnings
	if GDTSettings.get_setting("security/sanitize_tool_scripts"):
		return
	
	var lines = buffer.get_string_from_utf8().split("\n")
	var tool_idxs = get_tool_annotation_indexes(lines)
	
	if not tool_idxs.is_empty():
		var warning_message = "Tool script detected (%s). It can execute malicious code in your editor!" % path
		print(warning_message)
		
		if main and main.get_gui():
			main.get_gui().alert(warning_message)

func sanitize_buffer(buf: PackedByteArray) -> PackedByteArray:
	var text = buf.get_string_from_utf8()
	
	if GDTSettings.get_setting("security/sanitize_tool_scripts"):
		text = detool_code(text)
	
	return text.to_utf8_buffer()

static func is_script_line_ignored(line: String) -> bool:
	var trimmed = line.strip_edges(true, false)
	
	if trimmed.is_empty():
		return true
		
	if trimmed.contains("#"):
		return true
		
	return false

static func get_tool_annotation_indexes(lines: Array) -> Array:
	var res = []
	
	for line_i in lines.size():
		var line = lines[line_i]
		
		if not is_script_line_ignored(line) and not line.begins_with("@"):
			break
		
		if line.begins_with(TOOL_ANNOTATION):
			res.append(line_i)
	
	return res

static func detool_code(source: String) -> String:
	# TODO: Replace this with something more efficient. 
	# The function should iterate on the raw file buffer and
	# replace bytes instead of allocating a string
	
	var lines = source.split("\n")
	var indexes = get_tool_annotation_indexes(lines)
	
	for line_i in indexes:
		var line = lines[line_i]
		lines[line_i] = "#" + TOOL_ANNOTATION + line.erase(0, TOOL_ANNOTATION.length())
	
	return GDTUtils.join(lines, "\n")
