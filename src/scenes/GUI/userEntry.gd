@tool
extends HBoxContainer
class_name GDTGUIUser

var user: GDTUser

@onready var color_node = $color
@onready var name_node = $name
@onready var id_node = $id
@onready var ip_node = $ip/value
@onready var ip_toggle = $ip/toggle
@onready var rank_node = $rank

func _process(_delta: float) -> void:
	if user and not user.is_peer_connected():
		queue_free()

func set_ip_visible(state: bool) -> void:
	ip_node.secret = not state
	
	if state:
		ip_toggle.icon = GDTUserList.IMG_IP_VISIBLE
	else:
		ip_toggle.icon = GDTUserList.IMG_IP_HIDDEN

func is_ip_visible() -> bool:
	return not ip_node.secret

func set_user(user: GDTUser) -> void:
	color_node.color = user.color
	name_node.text = user.name
	id_node.text = str(user.id)
	
	self.user = user

	if user.peer:
		ip_node.text = user.peer.get_remote_address()
	else:
		ip_node.text = "unknown"
	
	rank_node.select(user.type)
	
	$actions/kick.pressed.connect(user.kick.bind(GDTUser.DisconnectReason.KICKED))

func toggle_ip_visibility() -> void:
	set_ip_visible(not is_ip_visible())
