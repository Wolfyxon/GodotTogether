@tool

### Class for data sent by users upon joining 
class_name GodotTogetherJoinData

var username: String

func as_dict() -> Dictionary:
    return {
        "username": username
    }

static func from_dict(dict: Dictionary) -> GodotTogetherJoinData:
    var res = GodotTogetherJoinData.new()

    for key in dict.keys():
        var val = dict[key]
        assert(val != null, "Invalid user data: %s is null: %s" % [key, dict])

    res.username = dict["username"]

    return res