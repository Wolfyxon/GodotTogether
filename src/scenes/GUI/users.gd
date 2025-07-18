@tool
extends ScrollContainer
class_name GDTUserList

var gui: GodotTogetherGUI

const IMG_IP_HIDDEN = preload("res://addons/GodotTogether/src/img/hidden.svg")
const IMG_IP_VISIBLE = preload("res://addons/GodotTogether/src/img/visible.svg")

@onready var template = $vbox/user

func _ready() -> void:
	await get_tree().process_frame
	
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
		gui.main.dual.users_listed.connect(_users_listed)
		gui.main.dual.user_connected.connect(add_user)
		gui.main.dual.user_disconnected.connect(remove_user)

	template.hide()

func _users_listed(users: Array[GDTUser]) -> void:
	clear()

	for user in users:
		add_user(user)

func add_user(user: GDTUser) -> void:
	if get_entry(user):
		push_warning("User %s alreay on the list" % user.id)
		return
	
	var clone: GDTGUIUser = $vbox/user.duplicate()
	clone.visible = true
	clone.name = str(user.id)
	
	$vbox.add_child(clone)
	clone.set_user(user)

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
