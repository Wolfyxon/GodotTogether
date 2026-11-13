@tool
extends VBoxContainer

var main: GodotTogether = null

func _process(_delta: float) -> void:
	if not main: return
	if not is_visible_in_tree(): return
	
	$spam.text = "Error spam detected: %s" % main.logger.is_spamming_errors()
	$avg.text = "Errors per frame: %s" % main.logger.get_avg_errors_per_frame()
	
	if $spamTest.button_pressed:
		push_error("test")
