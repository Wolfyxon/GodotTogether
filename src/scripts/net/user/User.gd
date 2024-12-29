@tool

### Class for connected users
class_name GodotTogetherUser

var id: int
var username: String
var peer: ENetPacketPeer
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

func kick():
    authenticated = false
    peer.peer_disconnect_later()