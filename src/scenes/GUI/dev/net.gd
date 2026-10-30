@tool
extends VBoxContainer

var main: GodotTogether = null

func _process(_delta: float) -> void:
	if not main: return
	if not visible: return
	
	var now = Time.get_unix_time_from_system()
	
	$pingTime.text = "Time since ping from server: %s" % (now - main.client.last_received_ping)
	
	if main.mp_override:
		$polling.text = "Polls per frame: %s" % main.mp_override.polls_per_frame

func _on_visibility_changed() -> void:
	if not main: return
	
	var text = "global: %s" % main.get_global_rpc_checksum()
	
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
		var script: Script = i.get_script()
		if not script: continue
		
		var conf = script.get_rpc_config()
		var funcs = conf.keys()
		if not funcs: continue
		
		print("----==== %s (%s RPC funcs) ====----" % [i.name, funcs.size()])
		
		var max_name_len = 0
		
		for func_name in funcs:
			if func_name.length() > max_name_len:
				max_name_len = func_name.length()
		
		for func_name in funcs:
			var sep = " ".repeat(max_name_len - func_name.length())
			var conf_str = str(conf[func_name]).replace("{ ", "{").replace(" }", "}")
			print("%s: %s%s" % [func_name, sep, conf_str])
		
		print("")


func _on_btn_copy_rpc_global_pressed() -> void:
	DisplayServer.clipboard_set(str(main.get_global_rpc_checksum()))

func _on_btn_copy_rpc_all_pressed() -> void:
	DisplayServer.clipboard_set($rpcChecksum.text)
