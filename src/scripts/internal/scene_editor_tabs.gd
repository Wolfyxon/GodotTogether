extends GDTNodeWrapper
class_name GDTEditorSceneTabs

var node: Control

func _wrapper_init() -> void:
	node = get_editor_node("EditorSceneTabs")
	if not node: return
	
	clear_colors()

func get_tab_bar() -> TabBar:
	return GDTUtils.get_descendant_with_class(node, "TabBar")

func get_color_rects() -> Array:
	var res = []
	
	for i in get_tab_bar().get_children(true):
		if i.has_meta("gdt_tab_color"):
			res.append(i)
	
	return res

func clear_colors() -> void:
	for i in get_color_rects():
		i.queue_free()

func set_tab_color(id: int, color: Color) -> void:
	var tb = get_tab_bar()
	var rect = tb.get_tab_rect(id)
	
	var clr = ColorRect.new()
	clr.set_meta("gdt_tab_color", true)
	clr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clr.color = color
	clr.color.a = 0.25
	
	tb.add_child(clr)
	
	clr.position = rect.position
	clr.size = rect.size
	clr.visible = true
	
