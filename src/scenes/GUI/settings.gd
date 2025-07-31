extends PopupPanel
class_name GDTSettingsGUI

var gui: GodotTogetherGUI

func _ready() -> void:
	if not gui: return
	if not gui.visuals_available(): return
	
	hide()
