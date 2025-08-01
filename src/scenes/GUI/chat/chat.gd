@tool
extends VBoxContainer
class_name GDTChat

@onready var messages = $scroll/msgs
@onready var usr_header = $scroll/msgs/userHeader
@onready var usr_message = $scroll/msgs/msg
@onready var system_message = $scroll/msgs/systemMsg

@onready var input = $controls/input

var main: GodotTogether
var last_user: GDTUser

var test_user = GDTUser.new(1)

func _ready() -> void:
	if not main: return
	
	test_user.name = "aaaaa"
	
	for i in get_templates():
		i.visible = false
	
	var scroll_style = EditorInterface.get_editor_theme().get_stylebox("panel", "Panel")
	$scroll.add_theme_stylebox_override("panel", scroll_style)

func _process(_delta: float) -> void:
	if input.has_focus():
		
		if Input.is_key_pressed(KEY_ENTER) and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_SHIFT):
			_send()

func _send() -> void:
	var text = input.text.strip_edges()
	
	if text == "":
		return
	
	add_user_message(text, test_user)
	input.clear()

func add_system_message(text: String):
	var msg = system_message.duplicate()
	msg.visible = true
	msg.text = text
	messages.add_child(msg)
	
	last_user = null

func add_user_message(text: String, user: GDTUser):
	if last_user != user:
		var header = usr_header.duplicate()
		
		header.visible = true
		header.modulate = user.color
		header.get_node("name").text = user.name
		
		messages.add_child(header)
		last_user = user
	
	var msg = usr_message.duplicate()
	var time = Time.get_datetime_dict_from_system()
	
	msg.visible = true
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
