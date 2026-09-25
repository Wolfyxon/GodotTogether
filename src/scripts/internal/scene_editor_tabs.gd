extends GDTNodeWrapper
class_name GDTEditorSceneTabs

var node: Control

var scene_colors := {}

func _wrapper_init() -> void:
	node = get_editor_node("EditorSceneTabs")
	if not node: return
	
	clear_colors()

# Signals don't work. Must be called in a loop
func update() -> void:
	clear_colors(false)
	
	for path in scene_colors.keys():
		set_scene_color(path, scene_colors[path])

func get_tab_bar() -> TabBar:
	return GDTUtils.get_descendant_with_class(node, "TabBar")

func get_color_rects() -> Array:
	var res = []
	
	for i in get_tab_bar().get_children(true):
		if i.has_meta("gdt_tab_color"):
			res.append(i)
	
	return res

func clear_colors(data := true) -> void:
	if data:
		scene_colors.clear()
	
	for i in get_color_rects():
		i.queue_free()

func get_scene_index(path: String) -> int:
	return EditorInterface.get_open_scenes().find(path)

func set_tab_color(id: int, color: Color) -> void:
	var tb = get_tab_bar()
	
	var clr = ColorRect.new()
	clr.set_meta("gdt_tab_color", true)
	clr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clr.color = color
	clr.color.a = 0.25
	
	tb.add_child(clr)
	align_color_rect_to_id(id, clr)

func align_color_rect_to_id(id: int, color_rect: ColorRect) -> void:
	var tb = get_tab_bar()
	var rect = tb.get_tab_rect(id)
	
	color_rect.position = rect.position
	color_rect.size = rect.size
	color_rect.visible = true

func set_scene_color(path: String, color: Color) -> void:
	scene_colors[path] = color
	var id = get_scene_index(path)
	
	if id != -1:
		set_tab_color(id, color)

func clear_scene_color(path: String, color: Color) -> void:
	scene_colors.erase(path)
	var id = get_scene_index(path)
	
	if id != -1:
		set_tab_color(id, color)
