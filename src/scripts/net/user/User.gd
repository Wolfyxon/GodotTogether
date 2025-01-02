@tool

### Class for connected users
class_name GodotTogetherUser

enum Type {
    HOST,
    GUEST
}

const FIELDS = [
    "id",
    "name",
    #"peer",
    "type",
    "joined_at",
    "authenticated_at",
    #"authenticated"
]

var id: int
var name: String
var peer: ENetPacketPeer
var type := Type.GUEST
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

func has_permission(permission: GodotTogether.Permission) -> bool:
    return authenticated and permission in permissions

func auth():
    assert(not authenticated, "User %d (%s) already authenticated" % [id, name])

    authenticated = true
    authenticated_at = Time.get_unix_time_from_system()

func kick():
    authenticated = false
    peer.peer_disconnect_later()

func is_server_user() -> bool:
    return peer != null

func as_dict() -> Dictionary:
    var res = {}

    for i in FIELDS:
        res[i] = i[i]

    return res

func get_type_as_string() -> String:
    return type_to_string(type)

static func type_to_string(type: Type) -> String:
    match type:
        Type.GUEST:
            return "Guest"
        Type.HOST:
            return "Host"

    return "error"

static func from_dict(dict: Dictionary) -> GodotTogetherUser:
    var user = GodotTogetherUser.new(dict["id"], null)

    for i in FIELDS:
        user[i] = dict[i]

    return user