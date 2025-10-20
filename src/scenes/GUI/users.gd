@tool
extends ScrollContainer
class_name GDTUserList

const IMG_IP_HIDDEN = preload("res://addons/GodotTogether/src/img/hidden.svg")
const IMG_IP_VISIBLE = preload("res://addons/GodotTogether/src/img/visible.svg")

var gui: GodotTogetherGUI

@onready var template = $vbox/user
@onready var ip_toggle = $vbox/header/ip/toggle

var global_ip_visible := false
var is_pending_tab := false

func _ready() -> void:
	await get_tree().process_frame

	if has_meta("is_pending"):
		is_pending_tab = get_meta("is_pending")
	
	if not gui: return
	if not gui.visuals_available(): return
	
	if not gui: return
	if not gui.visuals_available(): return
	
	var entry_rank_sel: OptionButton = template.get_node("rank")
	entry_rank_sel.clear()
	
	for i in GDTUser.Type.values():
		entry_rank_sel.add_item(
			GDTUser.type_to_string(i), 
			i
		)
	
	if gui.main:
		if is_pending_tab:
			var refresh_timer = Timer.new()
			refresh_timer.wait_time = 1.0
			refresh_timer.timeout.connect(_refresh_pending_users)
			add_child(refresh_timer)
			refresh_timer.start()
		else:
			gui.main.dual.users_listed.connect(_users_listed)
			gui.main.dual.user_connected.connect(add_user)
			gui.main.dual.user_disconnected.connect(remove_user)
		
	template.hide()

func _refresh_pending_users() -> void:
	if not gui or not gui.main: return
	
	var pending_users = gui.main.server.get_pending_users()
	
	for user in pending_users:
		if not get_entry(user):
			add_pending_user(user)
	
	for entry in get_entries():
		var user = entry.user
		if user and not user in pending_users:
			entry.queue_free()

func add_pending_user(user: GDTUser) -> void:
	if get_entry(user):
		return
	
	var clone: GDTGUIUser = template.duplicate()
	clone.visible = true
	clone.name = "pending_" + str(user.id)
	
	$vbox.add_child(clone)
	clone.set_user(user, gui, true)

func _users_listed(users: Array[GDTUser]) -> void:
	clear()
	for user in users:
		add_user(user)

func add_user(user: GDTUser) -> void:
	if get_entry(user):
		push_warning("User %s already on the list" % user.id)
		return
	
	var clone: GDTGUIUser = template.duplicate()
	clone.visible = true
	clone.name = str(user.id)
	
	$vbox.add_child(clone)
	clone.set_user(user, gui, false)

func remove_user(user: GDTUser) -> void:
	remove_by_id(user.id)

func get_entry(user: GDTUser) -> GDTGUIUser:
	for i in get_entries():
		if i.user == user:
			return i
		
	return null

func get_entry_by_id(id: int) -> GDTGUIUser:
	for i in get_entries():
		if i.user and i.user.id == id:
			return i
		
	return null

func remove_by_id(id: int) -> void:
	var entry = get_entry_by_id(id)
	if entry:
		entry.queue_free()

func get_entries() -> Array[GDTGUIUser]:
	var res: Array[GDTGUIUser] = []
	
	for i in $vbox.get_children():
		if i != template and i is GDTGUIUser:
			res.append(i)
	
	return res

func clear() -> void:
	for i in get_entries():
		i.queue_free()

func set_all_ip_visible(state: bool) -> void:
	global_ip_visible = state
	update_ip_toggle()
	
	for i in get_entries():
		i.set_ip_visible(state)

func update_ip_toggle() -> void:
	if global_ip_visible:
		ip_toggle.icon = IMG_IP_VISIBLE
	else:
		ip_toggle.icon = IMG_IP_HIDDEN

func toggle_all_ips() -> void:
	set_all_ip_visible(not global_ip_visible)
