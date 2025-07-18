@tool
extends HBoxContainer
class_name GDTGUIUser

var user: GDTUser

@onready var color_node = $color
@onready var name_node = $name
@onready var id_node = $id
@onready var ip_node = $ip/value
@onready var rank_node = $rank

func _process(_delta: float) -> void:
	if user and not user.is_peer_connected():
		queue_free()

func set_user(user: GDTUser):
	color_node.color = user.color
	name_node.text = user.name
	id_node.text = user.id
	ip_node.text = user.peer.get_remote_address()
	rank_node.select(user.type)
	
	$actions/kick.pressed.connect(user.kick)
