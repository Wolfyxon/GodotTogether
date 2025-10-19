@tool
extends HBoxContainer
class_name GDTGUIUser

var user: GDTUser
var gui: GodotTogetherGUI
var is_pending := false

func _ready() -> void:
	var parent = get_parent()
	while parent:
		if parent is GDTUserList:
			gui = parent.gui
			is_pending = parent.is_pending_tab
			break
		parent = parent.get_parent()

func set_user(user: GDTUser) -> void:
	self.user = user
	$color.color = user.color
	$name.text = user.name
	$id.text = str(user.id)
	
	if user.peer:
		$ip/value.text = user.peer.get_remote_address()
	else:
		$ip/value.text = "Local"
	
	var rank: OptionButton = $rank
	rank.selected = user.type
	
	if is_pending:
		setup_pending_actions()
	else:
		setup_normal_actions()

func setup_pending_actions() -> void:
	var actions = $actions
	var kick_btn = $actions/kick
	
	kick_btn.text = "Approve"
	kick_btn.pressed.disconnect(_on_kick_pressed)
	kick_btn.pressed.connect(_on_approve_pressed)
	
	var reject_btn = Button.new()
	reject_btn.text = "Reject"
	reject_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reject_btn.pressed.connect(_on_reject_pressed)
	actions.add_child(reject_btn)

func setup_normal_actions() -> void:
	if not $actions/kick.pressed.is_connected(_on_kick_pressed):
		$actions/kick.pressed.connect(_on_kick_pressed)

func set_ip_visible(state: bool) -> void:
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
	if gui and gui.main:
		gui.main.server.approve_pending_user(user)
		queue_free()

func _on_reject_pressed() -> void:
	if gui and gui.main:
		gui.main.server.reject_pending_user(user)
		queue_free()
