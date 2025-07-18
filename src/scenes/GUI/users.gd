@tool
extends ScrollContainer
class_name GDTUserList

var gui: GodotTogetherGUI

@onready var template = $vbox/user

func _ready() -> void:
	await get_tree().process_frame
	
	if not gui: return
	if not gui.visuals_available(): return

	template.hide()

func add_user(user: GDTUser):
	if get_entry(user):
		push_warning("User %s alreay on the list" % user.id)
		return
	
	var clone: GDTGUIUser = $vbox/user.duplicate()
	clone.visible = true
	clone.name = str(user.id)
	
	clone.set_user(user)
	$vbox.add_child(clone)

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
