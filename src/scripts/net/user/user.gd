@tool

class_name GDTUser

enum Type {
	HOST,
	EDITOR
}

enum DisconnectReason {
	# Do not reorder. Old versions will break
	UNKNOWN,
	KICKED,
	BANNED,
	PASSWORD_INVALID,
	REJECTED,
	JOINING_TOO_FAST,
	
	# Can reorder. Not yet released
	CLIENT_OUTDATED,
	SERVER_OUTDATED,
	APPROVE_TIMEOUT,
	ADDRESS_IN_USE
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
var type := Type.EDITOR
var color := Color.WHITE
var joined_at := -1.0
var authenticated_at := -1.0
var authenticated := false
var pending := false

var current_scene: String = ""
var current_script: String = ""

var _last_address: String = ""

var permissions: Array[GodotTogether.Permission] = [
	GodotTogether.Permission.EDIT_SCENES,
	GodotTogether.Permission.EDIT_SCRIPTS,
	GodotTogether.Permission.ADD_CUSTOM_FILES,
	GodotTogether.Permission.MODIFY_CUSTOM_FILES,
	GodotTogether.Permission.DELETE_SCRIPTS
]

func _init(_id: int, _peer: ENetPacketPeer = null, _main: GodotTogether = null):
	id = _id
	peer = _peer
	joined_at = Time.get_unix_time_from_system()
	main = _main
	
	color = Color(
		randf(),
		randf(),
		randf()
	)

func has_permission(permission: GodotTogether.Permission) -> bool:
	return authenticated and permission in permissions

func was_ever_authenticated() -> bool:
	return authenticated_at != -1

func get_address() -> String:
	if not peer:
		return "localhost"
	
	var res = peer.get_remote_address()
	
	if res.is_empty():
		return _last_address
	
	_last_address = normalize_address(res)
	return _last_address

func auth() -> void:
	assert(not authenticated, "User %d (%s) already authenticated" % [id, name])

	print("User %d authenticated as '%s'" % [id, name])

	authenticated = true
	authenticated_at = Time.get_unix_time_from_system()

	if type != Type.HOST:
		main.client.auth_successful.rpc_id(id)

		var user_dict = to_dict()
		
		main.server.auth_rpc(main.client.user_connected, [user_dict], [id])
		main.client.receive_user_list.rpc_id(id, main.server.get_user_dicts())
		main.dual._user_connected(self)


func kick(reason: DisconnectReason = DisconnectReason.KICKED) -> void:
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

func is_local() -> bool:
	if not main:
		return false
	
	return id == main.multiplayer.get_unique_id()

func to_dict() -> Dictionary:
	var res = {}

	for i in FIELDS:
		res[i] = self[i]

	return res

func get_type_as_string() -> String:
	return type_to_string(type)

static func disconnect_reason_to_string(reason: DisconnectReason) -> String:
	match reason:
		DisconnectReason.UNKNOWN:
			return "Connection lost"
		DisconnectReason.KICKED:
			return "Kicked by host"
		DisconnectReason.BANNED:
			return "You are banned"
		DisconnectReason.PASSWORD_INVALID:
			return "Invalid password"
		DisconnectReason.REJECTED:
			return "Connection rejected by host"
		DisconnectReason.APPROVE_TIMEOUT:
			return "Took too long waiting for approval"
		DisconnectReason.JOINING_TOO_FAST:
			return "You are joining too quickly"
		DisconnectReason.CLIENT_OUTDATED:
			return "You are running an older version of the plugin than the server"
		DisconnectReason.SERVER_OUTDATED:
			return "The host's plugin version is outdated"
		DisconnectReason.ADDRESS_IN_USE:
			return "Host does not allow multiple connections from the same IP address"
	
	return "Disconnected. Unknown status: %s" % reason

static func normalize_address(ip: String):
	if ip in ["0:0:0:0:0:0:0:1", "::1", "127.0.0.1"]:
		return "localhost"
		
	return ip

static func type_to_string(user_type: Type) -> String:
	var key: String = Type.find_key(user_type)

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
	
func reject(reason: DisconnectReason = DisconnectReason.REJECTED) -> void:
	assert(pending, "User %d (%s) is not pending" % [id, name])
	main.dual._user_rejected(self)
	kick(reason)
