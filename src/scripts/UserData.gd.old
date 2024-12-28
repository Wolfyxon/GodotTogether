extends Object
class_name GodotTogetherUserData

var username: String
var permission_level: GodotTogetherServer.PermissionLevel = GodotTogetherServer.PermissionLevel.GUEST

func _init(username: String, permission_level: GodotTogetherServer.PermissionLevel = GodotTogetherServer.PermissionLevel.GUEST):
	self.username = username
	self.permission_level = permission_level

# WARNING: Do not allow users to load their data
func load_data(data: Dictionary):
	var username: String = data["username"]
	var perm_lvl: GodotTogetherServer.PermissionLevel = data["permission_level"]
	
	assert(username, "Data citionary does not specify the username")
	if not perm_lvl: perm_lvl = permission_level
	
	self.username = username
	permission_level = perm_lvl

# Safe to use by users
func load_client_data(data: Dictionary):
	data["permission_level"] = null
	load_data(data)
