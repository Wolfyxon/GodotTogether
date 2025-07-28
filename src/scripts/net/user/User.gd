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
	PASSWORD_INVALID
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
var type := Type.GUEST
var color := Color.WHITE
var joined_at := -1.0
var authenticated_at := -1.0
var authenticated := false

var permissions: Array[GodotTogether.Permission] = [
	GodotTogether.Permission.EDIT_SCENES
]

func _init(id: int, peer: ENetPacketPeer):
	self.id = id
	self.peer = peer
	self.joined_at = Time.get_unix_time_from_system()
	
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
	peer.peer_disconnect_later(reason)

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
