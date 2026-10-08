@tool
extends EditorDock
class_name GDTUserListDock

enum UserAction {
	INFO,
	KICK,
	COPY_ID
}

const IMG_EDITING = preload("../../../../img/extLink.svg")
const IMG_SELF = preload("../../../../img/info.svg")
const IMG_IDLE = null

@onready var status_bar = $main/statusBar
@onready var user_count_label = $main/statusBar/vbox/userCount
@onready var status_label = $main/statusBar/vbox/status
@onready var inactive_label = $main/scroll/vbox/inactiveLabel

@onready var user_list = $main/scroll/vbox/users
@onready var user_template = $main/scroll/vbox/users/user

@onready var pending_list = $main/scroll/vbox/pendingUsers
@onready var pending_template = $main/scroll/vbox/pendingUsers/pendingUser

var gui: GodotTogetherGUI = null
var _inspector_dock: Control = null

func _ready() -> void:
	if not gui: return
	if not gui.main: return
	
	$main/header/btnMenu.pressed.connect(gui.open_menu)
	
	update_status()
	setup_signals()
	
	user_template.visible = false
	pending_template.visible = false
	
	custom_maximum_size.x = -1
	
	var role_btn: OptionButton = user_template.get_node("vbox/hbox/role")
	role_btn.clear()
	
	for user_type in GDTUser.Type.values():
		role_btn.add_item(GDTUser.type_to_string(user_type))
		
	EditorInterface.get_selection().selection_changed.connect(_selection_changed)

func _session_started() -> void:
	update_status()
	show()

func _selection_changed() -> void:
	if not gui: return
	if not gui.main: return
	
	var settings = gui.main.get_settings()
	if not settings: return
	
	var sel = EditorInterface.get_selection()
	
	var inspector_dock = get_inspector_dock()
	if not inspector_dock: return
	
	if not settings.get_setting("ui/show_inspector_on_select_while_in_user_dock"):
		return
	
	if visible and not sel.get_selected_nodes().is_empty():
		inspector_dock.show()

func _user_action(action: UserAction, user: GDTUser) -> void:
	match action:
		UserAction.INFO:
			gui.alert(GDTUtils.join([
				"Name: %s" % user.name,
				"Type: %s" % GDTUser.type_to_string(user.type),
				"Peer ID: %s" % user.id,
				"IP address: %s" % user.get_address(),
				"Joined at: %s" % Time.get_time_string_from_unix_time(int(user.joined_at))
			], "\n"), "User info")
		UserAction.KICK:
			user.kick()
		UserAction.COPY_ID:
			DisplayServer.clipboard_set(str(user.id))
			print("Copied user ID to clipboard")

func _user_goto(user: GDTUser) -> void:
	if user.current_scene:
		EditorInterface.open_scene_from_path(user.current_scene)
	
	if user.current_script:
		var script = load(user.current_script)
		
		if script:
			EditorInterface.edit_resource(script)

func _user_file_update(user: GDTUser, _path: String) -> void:
	update_user.call_deferred(user)

func update_user(user: GDTUser) -> void:
	var node = get_control_of_user(user)
	
	if node:
		update_user_control(node, user)

func setup_signals() -> void:
	gui.main.session_started.connect(_session_started)
	gui.main.session_ended.connect(update_status)
	gui.main.session_ended.connect(clear)
	
	gui.main.dual.users_listed.connect(load_users)
	gui.main.dual.user_connected.connect(add_user)
	gui.main.dual.user_disconnected.connect(remove_user)
	
	gui.main.dual.user_connected.connect(remove_pending)
	gui.main.dual.user_rejected.connect(remove_pending)
	gui.main.dual.user_pending.connect(add_pending)
	
	gui.main.dual.user_scene_changed.connect(_user_file_update)
	gui.main.dual.user_script_changed.connect(_user_file_update)

func get_inspector_dock() -> Control:
	if _inspector_dock:
		return _inspector_dock
		
	for i in get_parent().get_children():
		if i.get_class() == "InspectorDock":
			_inspector_dock = i
			break
			
	return _inspector_dock

func update_status() -> void:
	if not gui: return
	if not gui.main: return
	
	if not inactive_label: return
	
	if gui.main.server.is_active():
		status_label.text = "You are hosting"
	elif gui.main.client.is_active():
		status_label.text = "Connected"
	else:
		status_label.text = "Inactive"
	
	if gui.main.is_session_active():
		status_bar.modulate.a = 1
		inactive_label.visible = false
	else:
		status_bar.modulate.a = 0.5
		inactive_label.visible = true
	
	pending_list.visible = not gui.main.server.get_pending_users().is_empty()
	user_count_label.text = str(gui.main.dual.users.size())

func load_users(users: Array) -> void:
	clear()
	
	for i in users:
		add_user(i)

func add_user(user: GDTUser) -> void:
	var node = user_template.duplicate()
	var menu_btn: MenuButton = node.get_node("vbox/hbox/menu")
	var status_btn: Button = node.get_node("vbox/status")
	
	node.visible = true
	
	if user.is_local():
		node.self_modulate = Color(
			0, 1, 0,
			node.self_modulate.a
		)
	
	status_btn.pressed.connect(_user_goto.bind(user))
	
	setup_menu(menu_btn, user)
	update_user_control(node, user)
	
	node.set_meta("user_id", user.id)
	user_list.add_child(node)
	
	update_status()

func remove_user(user: GDTUser) -> void:
	var node = get_control_of_user(user)

	if node:
		node.queue_free()
	
	remove_pending(user)
	update_status()

func remove_pending(user: GDTUser) -> void:
	var node = get_control_of_pending(user)
	
	if node:
		node.queue_free()
		
	update_status()

func setup_menu(menu: MenuButton, user: GDTUser) -> void:
	menu.get_popup().id_pressed.connect(_user_action.bind(user))
	
	if not gui.main.server.is_active() or user.type == GDTUser.Type.HOST:
		menu.get_popup().set_item_disabled(UserAction.KICK, true)

func update_user_control(node: Control, user: GDTUser) -> void:
	var color_rect: ColorRect = node.get_node("vbox/hbox/color")
	var name_label: LineEdit = node.get_node("vbox/hbox/name")
	var role_btn: OptionButton = node.get_node("vbox/hbox/role")
	var status_btn: Button = node.get_node("vbox/status")
	
	color_rect.color = user.color
	name_label.text = user.name
	role_btn.selected = user.type
	
	
	if user.current_scene or user.current_script:
		status_btn.disabled = false
		
		var file = "<error>"
		var source_file = "<error>"
		const LENGTH_LIMIT = 20
		
		if user.current_script:
			source_file = user.current_script
		else:
			source_file = user.current_scene
		
		file = source_file
		
		if file.length() > LENGTH_LIMIT:
			file = "..." + file.substr(file.length() - LENGTH_LIMIT)
		
		status_btn.text = "Editing: %s" % file
		status_btn.tooltip_text = "Go to: %s" % source_file
		status_btn.icon = IMG_EDITING
		
	elif user.is_local():
		status_btn.text = "It's you"
		status_btn.tooltip_text = "Despite everything, it's still you"
		status_btn.disabled = true
		status_btn.icon = IMG_SELF
	else:
		status_btn.text = "..."
		status_btn.tooltip_text = "The user's status is unknown"
		status_btn.disabled = true
		status_btn.icon = IMG_IDLE

func get_control_of_user(user: GDTUser) -> Control:
	for i in user_list.get_children():
		if i.has_meta("user_id") and i.get_meta("user_id") == user.id:
			return i
	
	return

func add_pending(user: GDTUser) -> void:
	var node = pending_template.duplicate()
	
	node.get_node("vbox/top/name").text = user.name
	node.get_node("vbox/top/ip").text = user.get_address()
	
	node.get_node("vbox/actions/btnApprove").pressed.connect(user.approve)
	node.get_node("vbox/actions/btnReject").pressed.connect(user.reject)
	
	node.set_meta("user_id", user.id)
	node.visible = true
	
	pending_list.add_child(node)
	update_status()

func get_control_of_pending(user: GDTUser) -> Control:
	for i in pending_list.get_children():
		if i.has_meta("user_id") and i.get_meta("user_id") == user.id:
			return i
	
	return

func clear() -> void:
	user_count_label.text = "0"
	
	for i in user_list.get_children():
		if i != user_template and i != inactive_label:
			i.queue_free()
	
	for i in pending_list.get_children():
		if i != pending_template and i is not Label:
			i.queue_free()
