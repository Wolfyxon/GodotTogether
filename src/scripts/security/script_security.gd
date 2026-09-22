@tool
extends GDTComponent
class_name GDTScriptSecurity

const TOOL_ANNOTATION = "@tool"

var already_warned = []

func _ready() -> void:
	main.session_started.connect(reset)
	report_ready()

func reset() -> void:
	already_warned.clear()

func check_for_tool_script(path: String, buffer: PackedByteArray) -> void:
	if path in already_warned:
		return
	
	# Script is sanitized. No need for warnings
	if main.get_settings().get_setting("security/sanitize_tool_scripts"):
		return
	
	var lines = buffer.get_string_from_utf8().split("\n")
	var tool_idxs = get_tool_annotation_indexes(lines)
	
	if tool_idxs.is_empty():
		return
	
	var warning_message = "Tool script detected (%s). It can execute malicious code in your editor!" % path
	print(warning_message)
	
	if main and main.get_gui():
		main.get_gui().alert(warning_message)
		
	already_warned.append(path)

func sanitize_buffer(buf: PackedByteArray) -> PackedByteArray:
	var text = buf.get_string_from_utf8()
	
	if main.get_settings().get_setting("security/sanitize_tool_scripts"):
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
