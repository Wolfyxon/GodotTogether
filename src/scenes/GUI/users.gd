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

	template.hide()
	add_user(GDTUser.from_dict({
		"name": "a",
		"id": 0,
		"color": Color.RED,
		"type": GDTUser.Type.GUEST,
		"joined_at": 0,
		"authenticated_at": 0,
	}))

func add_user(user: GDTUser):
	if get_entry(user):
		push_warning("User %s alreay on the list" % user.id)
		return
	
	var clone: GDTGUIUser = $vbox/user.duplicate()
	clone.visible = true
	clone.name = str(user.id)
	
	$vbox.add_child(clone)
	clone.set_user(user)

func get_entry(user: GDTUser) -> GDTGUIUser:
	for i in get_entries():
		if i.user == user:
			return i
		
	return null

func get_entry_by_id(id: int) -> GDTGUIUser:
	for i in get_entries():
		if i.user.id == id:
			return i
		
	return null

func get_entries() -> Array[GDTGUIUser]:
	var res: Array[GDTGUIUser] = []
	
	for i in $vbox.get_children():
		if i != template and i is GDTGUIUser:
			res.append(i)
	
	return res

func clear():
	for i in get_entries():
		i.queue_free()
