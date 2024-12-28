@tool

### Class for connected users
class_name GodotTogetherUser

enum Permission {
    EDIT_SCRIPTS,
    EDIT_SCENES,
    DELETE_SCENES,
    DELETE_SCRIPTS,
    ADD_CUSTOM_FILES,
    MODIFY_CUSTOM_FILES
}

var id: int
var username: String
var peer: ENetPacketPeer
var permissions: Array[Permission] = []
var authenticated := false

func _init(id: int, peer: ENetPacketPeer):
    self.id = id
    self.peer = peer