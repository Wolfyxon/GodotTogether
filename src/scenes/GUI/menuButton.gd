class_name GDTMenuButton
extends Button

const ICON_CLIENT = preload("res://addons/GodotTogether/src/img/connect.svg")
const ICON_SERVER = preload("res://addons/GodotTogether/src/img/server.svg")
const ICON_SESSION = preload("res://addons/GodotTogether/src/img/play.svg")
const ICON_DISCONNECTED = preload("res://addons/GodotTogether/src/img/disconnected.svg")

var main_icon: Texture = null
var second_icon: Texture = null
var ticks := 0

func _init() -> void:
	self.text = "GodotTogether"
	reset()

func _ready() -> void:
	var t = Timer.new()
	
	t.wait_time = 1
	t.autostart = true
	t.timeout.connect(_update_icon)

	add_child(t)

func _update_icon() -> void:
	if ticks % 2 == 0 and second_icon:
		self.icon = second_icon
	else:
		self.icon = main_icon

	ticks += 1

func set_session_icon(icon: Texture) -> void:
	main_icon = ICON_SESSION
	second_icon = icon

func reset() -> void:
	main_icon = ICON_DISCONNECTED
	second_icon = null

	_update_icon()
