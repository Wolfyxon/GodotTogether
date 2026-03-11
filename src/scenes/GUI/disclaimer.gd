@tool
extends VBoxContainer
class_name GDTDisclaimer

@onready var checks = $checks.get_children()
@onready var btn_proceed = $btnProceed

var gui: GodotTogetherGUI

func _ready() -> void:
	await get_tree().process_frame
	
	if not gui: return
	if not gui.visuals_available(): return
	
	for i: CheckBox in checks:
		i.pressed.connect(_update)
		
	_update()

func _update() -> void:
	for i: CheckBox in checks:
		if not i.button_pressed:
			btn_proceed.disabled = true
			return
	
	btn_proceed.disabled = false 

func _on_text_meta_clicked(meta: String) -> void:
	OS.shell_open(meta)


func _on_btn_proceed_pressed() -> void:
	if not gui: return
	
	gui.get_menu().visible = true
	visible = false
	
	GDTSettings.set_setting("seen/disclaimer", true)
