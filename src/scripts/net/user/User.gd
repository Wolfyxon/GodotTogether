@tool

class_name GDTUser

enum Type {
	HOST,
	GUEST
}

enum DisconnectReason {
	UNKNOWN,
	KICKED,
	BANNED,
	PASSWORD_INVALID,
	REJECTED
}

const FIELDS = [
	"id",
	"name",
	#"peer",
	"color",
	"type",
	"joined_at",
	"authenticated_at",
	#"authenticated"
]

var id: int
var name: String
var peer: ENetPacketPeer
var main: GodotTogether = null
var type := Type.GUEST
var color := Color.WHITE
var joined_at := -1.0
var authenticated_at := -1.0
var authenticated := false
var pending := false

var permissions: Array[GodotTogether.Permission] = [
    GodotTogether.Permission.EDIT_SCENES,
    GodotTogether.Permission.EDIT_SCRIPTS,
    GodotTogether.Permission.ADD_CUSTOM_FILES,
    GodotTogether.Permission.MODIFY_CUSTOM_FILES,
    GodotTogether.Permission.DELETE_SCRIPTS
]

func _init(id: int, peer: ENetPacketPeer = null, main: GodotTogether = null):
	self.id = id
	self.peer = peer
	self.joined_at = Time.get_unix_time_from_system()
	self.main = main
	
	self.color = Color(
		randf(),
		randf(),
		randf()
	)

func has_permission(permission: GodotTogether.Permission) -> bool:
	return authenticated and permission in permissions

func auth() -> void:
	assert(not authenticated, "User %d (%s) already authenticated" % [id, name])

	authenticated = true
	authenticated_at = Time.get_unix_time_from_system()

func kick(reason: DisconnectReason = DisconnectReason.UNKNOWN) -> void:
	assert(peer, "Unable to kick user %s: missing peer" % id)
	
	authenticated = false

	if main:
		main.client.kick.rpc_id(id, reason)
	else:
		push_warning("Unable to send kick reason, main is null")

	peer.peer_disconnect_later()

	await EditorInterface.get_editor_main_screen().get_tree().create_timer(3).timeout

	if is_peer_connected(true):
		peer.peer_disconnect_now(reason)

func is_peer_connected(truly_connected := false) -> bool:
	if not peer:
		return true

	var state = peer.get_state()
	
	if truly_connected:
		return state != ENetPacketPeer.STATE_DISCONNECTED

	var dis = [
		ENetPacketPeer.STATE_DISCONNECTED,
		ENetPacketPeer.STATE_DISCONNECT_LATER,
		ENetPacketPeer.STATE_ACKNOWLEDGING_DISCONNECT
	]
	
	return not state in dis

func is_server_user() -> bool:
	return peer != null

func to_dict() -> Dictionary:
	var res = {}

	for i in FIELDS:
		res[i] = self[i]

	return res

func get_type_as_string() -> String:
	return type_to_string(type)

static func disconnect_reason_to_string(reason: DisconnectReason) -> String:
	match reason:
		DisconnectReason.KICKED:
			return "Kicked by host"
		DisconnectReason.BANNED:
			return "You are banned"
		DisconnectReason.PASSWORD_INVALID:
			return "Invalid password"
		DisconnectReason.REJECTED:
			return "Connection rejected by host"
	
	return "Connection lost"

static func type_to_string(type: Type) -> String:
	var key: String = Type.find_key(type)

	if key:
		return key.to_lower().capitalize()
	
	return "error"

static func from_dict(dict: Dictionary) -> GDTUser:
	var user = GDTUser.new(dict["id"], null)

	for i in FIELDS:
		user[i] = dict[i]

	return user

func approve() -> void:
	assert(pending, "User %d (%s) is not pending" % [id, name])
	assert(main, "Main is null")

	pending = false
	auth()
	
	print("User %d authenticated as '%s'" % [id, name])
	main.client.auth_successful.rpc_id(id)

	var user_dict = to_dict()

	main.dual.create_avatar_2d(user_dict)
	main.dual.create_avatar_3d(user_dict)

	main.server.auth_rpc(main.client.user_connected, [user_dict], [id])
	main.client.receive_user_list.rpc_id(id, main.server.get_user_dicts())
	main.dual._user_connected(self)
	
	main.toaster.push_toast("User %s (%s) approved and joined" % [name, id])

	for i in main.server.get_authenticated_users():
		if i.id == id: continue
		var dict = i.to_dict()

		main.dual.create_avatar_2d.rpc_id(id, dict)
		main.dual.create_avatar_3d.rpc_id(id, dict)

func reject(reason: DisconnectReason = DisconnectReason.REJECTED) -> void:
	assert(pending, "User %d (%s) is not pending" % [id, name])
	pending = false
	kick(reason)
