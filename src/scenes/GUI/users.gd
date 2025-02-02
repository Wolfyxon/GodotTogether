@tool
extends ScrollContainer

var main: GodotTogether

var template = $vbox/user

func _ready() -> void:
	if not main: return
	
	template.visible = false

func add_user(user: GodotTogetherUser):
	if get_entry(user):
		push_warning("User %s alreay on the list" % user.id)
		return
	
	var clone: GodotTogetherGUIUser = $vbox/user.duplicate()
	clone.visible = true
	clone.name = str(user.id)
	
	clone.set_user(user)
	$vbox.add_child(clone)

func get_entry(user: GodotTogetherUser) -> GodotTogetherGUIUser:
	for i in get_entries():
		if i.user == user:
			return i
		
	return null

func get_entries() -> Array[GodotTogetherGUIUser]:
	var res: Array[GodotTogetherGUIUser] = []
	
	for i in $vbox.get_children():
		if i != template and i is GodotTogetherGUIUser:
			res.append(i)
	
	return res

func clear():
	for i in get_entries():
		i.queue_free()
