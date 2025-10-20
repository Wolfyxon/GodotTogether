@tool
extends HBoxContainer
class_name GDTGUIUser

var user: GDTUser
var gui: GodotTogetherGUI
var is_pending := false

func set_user(user: GDTUser, gui_ref: GodotTogetherGUI, is_pending_entry: bool = false) -> void:
	self.user = user
	self.gui = gui_ref
	self.is_pending = is_pending_entry
	$color.color = user.color
	$name.text = user.name
	$id.text = str(user.id)
	
	if user.peer:
		$ip/value.text = user.peer.get_remote_address()
	else:
		$actions/normal/kick.disabled = true
		$ip/toggle.disabled = true
		$ip/value.secret = false

		if gui.main.server.is_active():
			$ip/value.text = "local"
		else:
			$ip/value.text = "N/A"
	
	var rank: OptionButton = $rank
	rank.selected = user.type
	
	$actions/normal.visible = not is_pending
	$actions/pending.visible = is_pending

	$actions/normal/kick.pressed.connect(_on_kick_pressed)
	$actions/pending/approve.pressed.connect(_on_approve_pressed)
	$actions/pending/reject.pressed.connect(_on_reject_pressed)

func set_ip_visible(state: bool) -> void:
	if $ip/toggle.disabled:
		return

	$ip/value.secret = not state
	
	if state:
		$ip/toggle.icon = GDTUserList.IMG_IP_VISIBLE
	else:
		$ip/toggle.icon = GDTUserList.IMG_IP_HIDDEN

func toggle_ip_visibility() -> void:
	set_ip_visible($ip/value.secret)

func _on_kick_pressed() -> void:
	if not gui or not gui.main: return
	
	if await gui.confirm("Are you sure you want to kick %s?" % user.name):
		user.kick()

func _on_approve_pressed() -> void:
	if gui and gui.main and user:
		user.approve()
		queue_free()

func _on_reject_pressed() -> void:
	if gui and gui.main and user:
		user.reject()
		queue_free()
