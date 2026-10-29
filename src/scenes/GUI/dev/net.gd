@tool
extends VBoxContainer

var main: GodotTogether = null

func _process(_delta: float) -> void:
	if not main: return
	if not visible: return
	
	var now = Time.get_unix_time_from_system()
	
	$pingTime.text = "Time since ping from server: %s" % (now - main.client.last_received_ping)

func _on_visibility_changed() -> void:
	if not main: return
	
	$rpcChecksum.text = "RPC checksum: %s" % main.get_global_rpc_checksum()

func _on_ignore_alive_ping_pressed() -> void:
	if not main: return
	
	main.client.ignore_alive_ping = $ignoreAlivePing.button_pressed
