@tool
extends GDTComponent
class_name GodotTogetherGUI

const IMG_HIDDEN = preload("../../img/hidden.svg")
const IMG_VISIBLE = preload("../../img/visible.svg")

const USER_LIST_DOCK_PATH = "res://addons/GodotTogether/src/scenes/GUI/docks/userListDock/user_list_dock.tscn"

var user_list_dock: GDTUserListDock = null

var scene_tree_editor = GDTSceneTreeEditor.new()
var scene_editor_tabs = GDTEditorSceneTabs.new()

func _ready() -> void:
	var menu_window = get_menu_window()
	var menu = get_menu()
	var disclaimer = menu_window.get_disclaimer()
	
	menu_window.gui = self
	menu.gui = self
	menu.users.gui = self
	menu.host_settings.gui = self
	menu.server_settings_tab.gui = self
	menu.get_node("session/tabs/Pending Users").gui = self
	disclaimer.gui = self
	
	if not main:
		return
	
	menu_window.visible = false
	menu_window.main = main
	menu.main = main
	
	if not menu_window.get_menu():
		component_error("get_menu() failed")
		return
	
	if not menu_window.get_settings_gui():
		component_error("get_settings_gui() failed")
		return
	
	setup_docks()
	report_ready()

func _process(_delta: float) -> void:
	scene_editor_tabs.update()
	
	if not Engine.is_editor_hint():
		get_menu_window().visible = true

func cleanup() -> void:
	scene_editor_tabs.clear_colors()
	scene_tree_editor.clear_colors()
	
	if user_list_dock:
		main.remove_dock(user_list_dock)
		user_list_dock.queue_free.call_deferred()

func setup_docks() -> void:
	var scene = load(USER_LIST_DOCK_PATH)
	
	if not scene:
		GDTUtils.printerr_stack("Unable to load scene: %s" % USER_LIST_DOCK_PATH)
		return
	
	user_list_dock = scene.instantiate()
	user_list_dock.gui = self
	
	main.add_dock(user_list_dock)

func get_menu() -> GDTMenu:
	return get_menu_window().get_menu()

func get_menu_window() -> GDTMenuWindow:
	return $mainMenu

func add_window(window: Window) -> void:
	var menu_w = get_menu_window()
	var settings_w = $mainMenu/settings
	
	if menu_w.visible:
		if settings_w.visible:
			settings_w.add_child(window)
		else:
			menu_w.add_child(window)
	else:
		add_child(window)

func open_menu() -> void:
	var window = get_menu_window()
	window.popup()
	window.checked_reflow()

func progress(description := "Please wait...") -> GDTProgressPopup:
	var popup = GDTProgressPopup.new(description)
	
	add_window(popup)
	popup.popup_centered()
	
	return popup

func alert(text: String, title := "GodotTogether") -> AcceptDialog:
	var popup := AcceptDialog.new()
	
	popup.dialog_text = text
	popup.title = title
	popup.min_size.x = 400
	popup.always_on_top = true
	popup.unresizable = true
	
	add_window(popup)
	popup.popup_centered()

	popup.canceled.connect(popup.queue_free)
	popup.confirmed.connect(popup.queue_free)

	return popup

func confirm(text: String) -> bool:
	var p := ConfirmationDialog.new()
	p.dialog_text = text
	p.always_on_top = true
	p.unresizable = true
	
	p.confirmed.connect(p.set_meta.bind("status", true))
	p.canceled.connect(p.set_meta.bind("status", false))
	
	add_window(p)
	p.popup_centered()
	
	while not p.has_meta("status"):
		await get_tree().process_frame
	
	p.queue_free()
	
	return p.get_meta("status")

func visuals_available() -> bool:
	return main or not Engine.is_editor_hint() 
