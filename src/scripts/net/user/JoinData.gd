@tool

### Class for data sent by users upon joining 
class_name GodotTogetherJoinData

var username: String

func as_dict() -> Dictionary:
    return {
        "username": username
    }