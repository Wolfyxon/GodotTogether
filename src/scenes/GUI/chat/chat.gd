@tool
extends VBoxContainer
class_name GDTChat

const IMG_JOINED = preload("res://addons/GodotTogether/src/img/play.svg")
const IMG_DISCONNECTED = preload("res://addons/GodotTogether/src/img/arrowLeft.svg")
const MAX_MESSAGE_LEN = 2048

@onready var messages = $scroll/msgs
@onready var usr_header = $scroll/msgs/userHeader
@onready var usr_message = $scroll/msgs/msg
@onready var system_message = $scroll/msgs/systemMsg
@onready var user_notification = $scroll/msgs/userNotif

@onready var input = $controls/inputContainer/input

var main: GodotTogether
var last_user: GDTUser

func _ready() -> void:
	if not main: return

	for i in get_templates():
		i.visible = false
	
	var scroll_style = EditorInterface.get_editor_theme().get_stylebox("panel", "Panel")
	$scroll.add_theme_stylebox_override("panel", scroll_style)

	main.server.hosting_started.connect(add_system_message.bind("Server started"))
	main.client.auth_succeed.connect(add_system_message.bind("Connected to the server"))

	main.dual.user_connected.connect(add_user_notification.bind(IMG_JOINED, "joined"))
	main.dual.user_disconnected.connect(add_user_notification.bind(IMG_DISCONNECTED, "disconnected"))

	clear()

func _process(_delta: float) -> void:
	if input.has_focus():
		
		if Input.is_key_pressed(KEY_ENTER) and not Input.is_key_pressed(KEY_CTRL) and not Input.is_key_pressed(KEY_SHIFT):
			_send()

func _send() -> void:
	var text = input.text.strip_edges()
	
	if text == "": return
	if text.length() > MAX_MESSAGE_LEN: return
	
	if main.server.is_active():
		main.server.submit_chat_message(1, text)
	else:
		main.server.receive_chat_message.rpc_id(1, text)

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
		header.get_node("id").text = str(user.id)
		
		messages.add_child(header)
		last_user = user
	
	var msg = usr_message.duplicate()
	var time = Time.get_datetime_dict_from_system()
	
	msg.visible = true
	msg.get_node("content").text = text
	msg.get_node("time").text = "%s:%s" % [time["hour"], time["minute"]]
	
	messages.add_child(msg)

func add_user_notification(user: GDTUser, icon: Texture, status: String) -> void:
	var msg = user_notification.duplicate()
	var user_label = msg.get_node("user")
	
	msg.get_node("icon").texture = icon
	msg.get_node("status").text = status
	
	user_label.text = "%s (%s)" % [user.name, str(user.id)]
	user_label.modulate = user.color

	msg.visible = true
	messages.add_child(msg)

@rpc("authority", "reliable")
func receive_user_message(text: String, id: int):
	var user = main.dual.get_user_by_id(id)
	if not user: return

	add_user_message(text, user)

func get_templates() -> Array[Control]:
	return [
		usr_header,
		usr_message,
		system_message,
		user_notification
	]

func clear():
	var templates = get_templates()
	
	for i in messages.get_children():
		if not i in templates:
			i.queue_free()

	add_system_message("Welcome to the GodotTogether chat! \nRemember to be nice and civil.")
