@tool
extends PopupPanel
class_name GodotTogetherMainMenu

var main:GodotTogether

var join_ip = $tabs/start/vbox/type/join/address/ip
var join_port = $tabs/start/vbox/type/join/address/port
var join_password = $tabs/start/vbox/type/join/password

var host_port = $tabs/start/vbox/type/host/smallConfig/port
var host_max_clients = $tabs/start/vbox/type/host/smallConfig/maxClients
var host_password = $tabs/start/vbox/type/host/password

func _ready():
	pass

func _process(delta):
	if not Engine.is_editor_hint(): popup()

func toggle():
	if not visible: popup()
	else: visible = false


func _on_btn_host_pressed():
	pass # Replace with function body.


func _on_btn_join_pressed():
	pass # Replace with function body.
