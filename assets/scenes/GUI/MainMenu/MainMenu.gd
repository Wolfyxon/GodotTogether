@tool
extends PopupPanel
class_name GodotTogetherMainMenu

var main:GodotTogether

@onready var join_ip = $tabs/start/vbox/joinOrHost/tabs/join/address/ip
@onready var join_port = $tabs/start/vbox/joinOrHost/tabs/join/address/port
@onready var join_password = $tabs/start/vbox/joinOrHost/tabs/join/password

@onready var host_port = $tabs/start/vbox/joinOrHost/tabs/host/smallConfig/port
@onready var host_max_clients = $tabs/start/vbox/joinOrHost/tabs/host/smallConfig/maxClients
@onready var host_password = $tabs/start/vbox/joinOrHost/tabs/host/password

func _ready():
	pass

func _process(delta):
	if not Engine.is_editor_hint(): popup()
	if Engine.is_editor_hint() and EditorInterface.get_edited_scene_root() == self: return

	$tabs/start/vbox/joinOrHost/tabs/join/btnJoin.disabled = (join_ip.text == "")

func toggle():
	if not visible: popup()
	else: visible = false


func _on_btn_host_pressed():
	pass # Replace with function body.


func _on_btn_join_pressed():
	pass # Replace with function body.
