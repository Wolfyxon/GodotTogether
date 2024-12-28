@tool
extends PopupPanel
class_name GodotTogetherMainMenu

var main: GodotTogether

@onready var username_input = $tabs/start/vbox/username

@onready var join_ip = $tabs/start/vbox/joinOrHost/tabs/join/address/ip
@onready var join_port = $tabs/start/vbox/joinOrHost/tabs/join/address/port
@onready var join_password = $tabs/start/vbox/joinOrHost/tabs/join/password
@onready var join_btn = $tabs/start/vbox/joinOrHost/tabs/join/btnJoin

@onready var host_port = $tabs/start/vbox/joinOrHost/tabs/host/smallConfig/port
@onready var host_max_clients = $tabs/start/vbox/joinOrHost/tabs/host/smallConfig/maxClients
@onready var host_password = $tabs/start/vbox/joinOrHost/tabs/host/password
@onready var host_btn = $tabs/start/vbox/joinOrHost/tabs/host/btnHost

@onready var cover = $tabs/start/vbox/joinOrHost/cover

func _ready():
	if Engine.is_editor_hint() and not main: return

	join_ip.text = GodotTogetherSettings.get_setting("last_server")
	join_port.value = GodotTogetherSettings.get_setting("last_port")
	username_input.text = GodotTogetherSettings.get_setting("username")

func _process(delta):
	if not Engine.is_editor_hint() and not visible: popup()
	if Engine.is_editor_hint() and EditorInterface.get_edited_scene_root() == self: return

	join_btn.disabled = (join_ip.text == "") or cover.visible
	host_btn.disabled = cover.visible
	
	cover.visible = (main and main.is_session_active())
	
func toggle():
	if not visible: popup()
	else: visible = false


func _on_btn_host_pressed():
	if not main: return
	if main.is_session_active(): return
	
	var err = main.server.start_hosting(host_port.value, host_max_clients.value)
	if err: push_error("Cannot host. Err: " + str(err))

func _on_btn_join_pressed():
	if not main: return
	if main.is_session_active(): return

	GodotTogetherSettings.set_setting("last_server", join_ip.text)
	GodotTogetherSettings.set_setting("last_port", join_port.value)
	
	var err = main.client.join(join_ip.text, join_port.value, GodotTogetherJoinData.from_dict({
		"username": username_input.text,
		"password": join_password.text
	}))

	assert(not err, "Cannot join. Err: %d" % err)
	

func _on_btn_stop_pressed():
	if not main: return
	main.close_connection()


func _on_username_text_changed(new_text):
	GodotTogetherSettings.set_setting("username", new_text)
