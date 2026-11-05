@tool
extends GDTEncodableData
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
	
	CLIENT_OUTDATED,
	SERVER_OUTDATED,
	
	APPROVE_TIMEOUT,
	ADDRESS_IN_USE,
	RPC_CHECKSUM_MISMATCH,
	INVALID,
	
	# Can reorder. Not yet released
	
	TIMEOUT
}

var id: int = -1
var name: String = ""
var peer: PacketPeer = null
var main: GodotTogether = null
var type := Type.EDITOR
var color := Color.WHITE
var joined_at := -1.0
var last_ping := 0.0
var authenticated_at := -1.0
var authenticated := false
var pending := false

var current_scene: String = ""
var current_script: String = ""
var current_script_line: int = 0
var current_script_column: int = 0

var _last_address: String = ""

var permissions: Array[GodotTogether.Permission] = [
	GodotTogether.Permission.EDIT_SCENES,
	GodotTogether.Permission.EDIT_SCRIPTS,
	GodotTogether.Permission.ADD_CUSTOM_FILES,
	GodotTogether.Permission.MODIFY_CUSTOM_FILES,
	GodotTogether.Permission.DELETE_SCRIPTS
]

func _init(_id: int, _peer: PacketPeer = null, _main: GodotTogether = null):
	var now = Time.get_unix_time_from_system()
	
	id = _id
	peer = _peer
	joined_at = now
	last_ping = now
	main = _main
	
	color = Color(
		randf(),
		randf(),
		randf()
	)

func get_encodable_fields() -> Array:
	return [
		"id",
		"name",
		#"peer",
		"color",
		"type",
		"joined_at",
		"authenticated_at",
		"current_scene",
		"current_script",
		"current_script_line",
		"current_script_column"
		#"authenticated"
	]

func got_ping() -> void:
	last_ping = Time.get_unix_time_from_system()

func has_permission(permission: GodotTogether.Permission) -> bool:
	return authenticated and permission in permissions

func was_ever_authenticated() -> bool:
	return authenticated_at != -1

func get_address() -> String:
	if not peer:
		return "localhost"
	
	if peer is ENetPacketPeer:
		var res = peer.get_remote_address()
		
		if res.is_empty():
			return _last_address
		
		_last_address = normalize_address(res)
	else:
		_last_address = "<unknown>"
	
	return _last_address

func auth() -> void:
	if authenticated:
		GDTUtils.printerr_stack("Already authenticated: %s %s" % [id, name])
		return

	print("User %d authenticated as '%s'" % [id, name])

	authenticated = true
	authenticated_at = Time.get_unix_time_from_system()

	if type != Type.HOST:
		main.server._user_authenticated(self)

func kick(reason: DisconnectReason = DisconnectReason.KICKED) -> void:
	if id == 1:
		GDTUtils.printerr_stack("Attempt to kick host")
		return
	
	authenticated = false

	if main:
		main.client._s2c_receive_kick_reason.rpc_id(id, reason)
	else:
		push_warning("Unable to send kick reason, main is null")

	if not peer:
		GDTUtils.printerr_stack("Cannot kick %s: missing peer object" % id)
		return
	
	disconnect_peer()

func try_disconnect_peer() -> void:
	if peer is ENetPacketPeer:
		peer.peer_disconnect_later()
	elif main:
		main.multiplayer.multiplayer_peer.disconnect_peer(id)
	else:
		GDTUtils.printerr_stack("try_disconnect_peer() failed: main is null")

func force_disconnect_peer() -> void:
	if peer is ENetPacketPeer:
		peer.peer_disconnect_now()
	
	if not is_peer_connected(true):
		return
	
	if not main:
		GDTUtils.printerr_stack("Unable to kick peer %s. main is null" % id)
		return
	
	if is_peer_connected(true):
		main.multiplayer.multiplayer_peer.disconnect_peer(id)
	
	if is_peer_connected(true):
		main.multiplayer.multiplayer_peer.disconnect_peer(id, true)

func disconnect_peer() -> void:
	authenticated = false
	try_disconnect_peer()
	
	await GDTUtils.get_tree().create_timer(3).timeout
	
	if not is_peer_connected(true):
		return
		
	force_disconnect_peer()

func is_peer_connected(truly_connected := false) -> bool:
	if not peer:
		return true
	
	if peer is ENetPacketPeer:
		var state = peer.get_state()
		
		if truly_connected:
			return state != ENetPacketPeer.STATE_DISCONNECTED

		var dis = [
			ENetPacketPeer.STATE_DISCONNECTED,
			ENetPacketPeer.STATE_DISCONNECT_LATER,
			ENetPacketPeer.STATE_ACKNOWLEDGING_DISCONNECT
		]
		
		return not state in dis
	else:
		GDTUtils.printerr_stack("No way to tell if peer is connected: %s" % peer.get_class())
	
	return false
func is_local() -> bool:
	if not main:
		GDTUtils.printerr_stack("Unable to check if user is local. main is null")
		return false
	
	return id == main.multiplayer.get_unique_id()

func get_type_as_string() -> String:
	return type_to_string(type)

static func disconnect_reason_to_string(reason: DisconnectReason) -> String:
	match reason:
		DisconnectReason.UNKNOWN, DisconnectReason.TIMEOUT:
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
		DisconnectReason.RPC_CHECKSUM_MISMATCH:
			return "RPC checksum mismatch. You and the host are running different versions of the plugin."
		DisconnectReason.INVALID:
			return "Your client sent invalid data to the server"
	
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
	
	if not user.apply_dict(dict):
		return
	
	return user

static func from_dict_bulk(dicts: Array, _main: GodotTogether = null) -> Array[GDTUser]:
	var res: Array[GDTUser] = []
	
	for i in dicts:
		var user = GDTUser.from_dict(i)
		user.main = _main
		
		if user:
			res.append(user)
	
	return res

func approve() -> void:
	if not pending:
		GDTUtils.printerr_stack("User %d (%s) is not pending" % [id, name])
		return
	
	if not main:
		GDTUtils.printerr_stack("main is null")
		return

	pending = false
	auth()
	
func reject(reason: DisconnectReason = DisconnectReason.REJECTED) -> void:
	main.dual._user_rejected(self)
	kick(reason)
