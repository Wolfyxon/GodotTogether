@tool
extends VBoxContainer
class_name GDTServerSettingsUi

@onready var port_input: SpinBox = $port/value
@onready var max_users_input: SpinBox = $max_users/value
@onready var password_input: LineEdit = $password/value
@onready var password_toggle: Button = $password/toggle

@export var server_active = false

var gui: GodotTogetherGUI
var controls: Array = []

func _ready() -> void:
	await get_tree().process_frame
	
	if not gui:
		return
	
	update_settings_mode()
	
	register_control($port/value, "server/port")
	register_control($max_users/value, "server/max_users")
	register_control($password/value, "server/password")
	register_control($approveUsers, "server/require_approval")

func register_control(node: Control, path: String):
	node.set_meta("setting", path)
	GDTSettings.make_setting_control(node, path)
	controls.append(node)

func update_settings_mode() -> void:
	$port/value.editable = not server_active
	$max_users/value.editable = not server_active

func load_settings() -> void:
	for i in controls:
		GDTSettings.update_control(i, i.get_meta("setting"))

func _on_password_toggled(toggled_on: bool) -> void:
	password_input.secret = not toggled_on
	
	if toggled_on:
		password_toggle.icon = GodotTogetherGUI.IMG_VISIBLE
	else:
		password_toggle.icon = GodotTogetherGUI.IMG_HIDDEN
