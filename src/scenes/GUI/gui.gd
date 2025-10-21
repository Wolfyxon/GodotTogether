@tool
extends Node
class_name GodotTogetherGUI

var main: GodotTogether

func _ready() -> void:
	var menu_window = get_menu_window()
	var menu = get_menu()
	var disclaimer = menu_window.get_disclaimer()
	
	menu_window.gui = self
	menu.gui = self
	menu.users.gui = self
	menu.get_node("session/tabs/Pending Users").gui = self
	disclaimer.gui = self
	
	if main:
		menu_window.visible = false
		menu_window.main = main
		menu.main = main
		
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		get_menu_window().visible = true

func get_menu() -> GDTMenu:
	return get_menu_window().get_menu()

func get_menu_window() -> GDTMenuWindow:
	return $mainMenu

func alert(text: String, title := "GodotTogether") -> AcceptDialog:
	var popup := AcceptDialog.new()
	
	popup.dialog_text = text
	popup.title = title
	popup.min_size.x = 300
	popup.always_on_top = true
	
	var menu_w = get_menu_window()
	
	if menu_w.visible:
		menu_w.add_child(popup)
	else:
		add_child(popup)
	
	popup.popup_centered()

	popup.canceled.connect(popup.queue_free)
	popup.confirmed.connect(popup.queue_free)

	return popup

func confirm(text: String) -> bool:
	var p := ConfirmationDialog.new()
	p.dialog_text = text
	
	
	p.confirmed.connect(p.set_meta.bind("status", true))
	p.canceled.connect(p.set_meta.bind("status", false))
	
	var menu_w = get_menu_window()
	
	if menu_w.visible:
		menu_w.add_child(p)
	else:
		add_child(p)

	p.popup_centered()
	
	while not p.has_meta("status"):
		await get_tree().process_frame
	
	p.queue_free()
	
	return p.get_meta("status")
	

func visuals_available() -> bool:
	return main or not Engine.is_editor_hint() 
