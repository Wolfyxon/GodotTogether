@tool
extends GDTComponent
class_name GDTExtras

var halloween: GDTHalloweenEvent = null

func _ready() -> void:
	report_ready() # This script isn't essential for the plugin to function
	
	if is_halloween():
		start_halloween()

func is_halloween() -> bool:
	var date = Time.get_datetime_dict_from_system()
	
	return (
		(
			date["month"] == 10 and
			date["day"] > 30
		) or
		(
			date["month"] == 11 and
			date["day"] == 1
		)
	)

func start_halloween() -> void:
	halloween = GDTHalloweenEvent.new()
	halloween.main = main
	add_child(halloween)
