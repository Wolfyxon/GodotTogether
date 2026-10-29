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
		var script: Script = i.get_script()
		if not script: continue
		
		var conf = script.get_rpc_config()
		var funcs = conf.keys()
		if not funcs: continue
			
		print("----==== %s ====----" % i.name)
		
		var max_name_len = 0
		
		for func_name in funcs:
			if func_name.length() > max_name_len:
				max_name_len = func_name.length()
		
		for func_name in funcs:
			var sep = " ".repeat(max_name_len - func_name.length())
			var conf_str = str(conf[func_name]).replace("{ ", "{").replace(" }", "}")
			print("%s: %s%s" % [func_name, sep, conf_str])
		
		print("")
