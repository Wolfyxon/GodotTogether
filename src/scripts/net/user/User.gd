@tool

### Class for connected users
class_name GodotTogetherUser

var id: int
var username: String
var peer: ENetPacketPeer
var authenticated := false

var permissions: Array[GodotTogether.Permission] = [
    GodotTogether.Permission.EDIT_SCENES
]

func _init(id: int, peer: ENetPacketPeer):
    self.id = id
    self.peer = peer

func has_permission(permission: GodotTogether.Permission) -> bool:
    return authenticated and permission in permissions

func kick():
    authenticated = false
    peer.peer_disconnect_later()