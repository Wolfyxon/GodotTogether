@tool
extends EditorDock
class_name GDTUserListDock

enum UserAction {
	KICK,
	COPY_ID
}

@onready var user_count_label = $main/statusBar/vbox/userCount
@onready var status_label = $main/statusBar/vbox/usersLabel

@onready var user_list = $main/scroll/vbox
@onready var user_template = $main/scroll/vbox/user

var gui: GodotTogetherGUI = null

func _ready() -> void:
	if not gui: return
	if not gui.main: return
	
	$main/header/btnMenu.pressed.connect(gui.open_menu)
	
	user_template.visible = false
	custom_maximum_size.x = -1
	
	gui.main.dual.users_listed.connect(load_users)
	gui.main.dual.user_connected.connect(add_user)
	gui.main.dual.user_disconnected.connect(remove_user)
	gui.main.session_ended.connect(clear)
	
	var role_btn: OptionButton = user_template.get_node("vbox/hbox/role")
	role_btn.clear()
	
	for user_type_name in GDTUser.Type.keys():
		role_btn.add_item(user_type_name)

func _user_action(action: UserAction, user: GDTUser) -> void:
	match action:
		UserAction.KICK:
			user.kick()
		UserAction.COPY_ID:
			DisplayServer.clipboard_set(str(user.id))
			print("Copied user ID to clipboard")

func load_users(users: Array) -> void:
	clear()
	
	for i in users:
		add_user(i)

func add_user(user: GDTUser) -> void:
	var node = user_template.duplicate()
	var menu_btn: MenuButton = node.get_node("vbox/hbox/menu")
	
	node.visible = true
	
	setup_menu(menu_btn, user)
	update_user_control(node, user)
	user_list.add_child(node)

func remove_user(user: GDTUser) -> void:
	var node = get_control_of_user(user)
	
	if node:
		node.queue_free()

func setup_menu(menu: MenuButton, user: GDTUser) -> void:
	menu.get_popup().id_pressed.connect(_user_action.bind(user))
	
	if not gui.main.server.is_active() or user.type == GDTUser.Type.HOST:
		menu.get_popup().set_item_disabled(UserAction.KICK, true)

func update_user_control(node: Control, user: GDTUser) -> void:
	var color_rect: ColorRect = node.get_node("vbox/hbox/color")
	var name_label: LineEdit = node.get_node("vbox/hbox/name")
	var role_btn: OptionButton = node.get_node("vbox/hbox/role")
	
	color_rect.color = user.color
	name_label.text = user.name
	role_btn.selected = user.type

func get_control_of_user(user: GDTUser) -> Control:
	for i in user_list.get_children():
		if i.has_meta("user_id") and i.get_meta("user_id") == user.id:
			return i
	
	return

func clear() -> void:
	user_count_label.text = "0"
	
	for i in user_list.get_children():
		if i != user_template:
			i.queue_free()
