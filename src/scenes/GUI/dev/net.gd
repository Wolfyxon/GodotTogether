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
	
	var text = "RPC checksum: \nglobal: %s" % main.get_global_rpc_checksum()
	
	for i in main.components:
		if not i: continue
		text += "\n- %s: %s" % [i.name, GDTUtils.get_rpc_checksum(i)] 
	
	
	$rpcChecksum.text = text

func _on_ignore_alive_ping_pressed() -> void:
	if not main: return
	
	main.client.ignore_alive_ping = $ignoreAlivePing.button_pressed

func _on_btn_rpc_config_pressed() -> void:
	if not main: return
	
	for i in main.components:
		print("--- %s ---" % i.name)
		
		var script: Script = i.get_script()
		
		if not script:
			print("< no script >")
			continue
		print(JSON.stringify(script.get_rpc_config()), "  ", false)
