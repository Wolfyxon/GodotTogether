@tool

### Class for connected users
class_name GodotTogetherUser

var id: int
var username: String
var peer: ENetPacketPeer
var permissions: Array[GodotTogether.Permission] = []
var authenticated := false

func _init(id: int, peer: ENetPacketPeer):
    self.id = id
    self.peer = peer

func has_permission(permission: GodotTogether.Permission) -> bool:
    return authenticated and permission in permissions