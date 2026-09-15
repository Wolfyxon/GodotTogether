@tool
extends Node
class_name GDTComponent

var main: GodotTogether
var component_ready = false

var _init_stack: Array = []

# Do not make the arguments mandatory or scenes won't work
func _init(_main: GodotTogether = null, _name: String = "") -> void:
	main = _main
	
	if _name:
		name = "GodotTogether_" + _name
	
	if main:
		main.tree_exiting.connect(queue_free)
	
	ready.connect(_component_ready)
	_init_stack = GDTUtils.get_stack_lines()

func _component_ready() -> void:
	if not name or name.contains("@"):
		var stack = GDTUtils.join(_init_stack, "\n")
		# Single print because the lines could get mixed
		printerr("Component should have a name\n-- _init traceback --\n%s\n" % stack)

func report_ready() -> void:
	component_ready = true
