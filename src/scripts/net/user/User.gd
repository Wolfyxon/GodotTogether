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
var permissions: Array[Permission] = []
var ip: String
var authenticated := false