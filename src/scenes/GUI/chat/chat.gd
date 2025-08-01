@tool
extends VBoxContainer
class_name GDTChat

@onready var messages = $scroll/msgs
@onready var usr_header = $scroll/msgs/userHeader
@onready var usr_message = $scroll/msgs/msg
@onready var system_message = $scroll/msgs/systemMsg

var main: GodotTogether
var last_user: GDTUser

func _ready() -> void:
	if not main: return
	
	for i in get_templates():
		i.visible = false
	
	var scroll_style = EditorInterface.get_editor_theme().get_stylebox("panel", "Panel")
	$scroll.add_theme_stylebox_override("panel", scroll_style)

func add_system_message(text: String):
	var msg = system_message.duplicate()
	msg.text = text
	messages.add_child(msg)
	
	last_user = null

func add_user_message(text: String, user: GDTUser):
	if last_user != user:
		var header = usr_header.duplicate()
		
		header.modulate = user.color
		header.get_node("name").text = user.name
		
		messages.add_child(header)
	
	var msg = usr_message.duplicate()
	var time = Time.get_datetime_dict_from_system()
	
	msg.get_node("content").text = text
	msg.get_node("time").text = "%s:%s" % [time["hour"], time["minute"]]
	
	messages.add_child(msg)

func get_templates() -> Array[Control]:
	return [
		usr_header,
		usr_message,
		system_message
	]

func clear():
	var templates = get_templates()
	
	for i in messages.get_children():
		if not i in templates:
			i.queue_free()
