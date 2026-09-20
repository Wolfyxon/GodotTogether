@tool
extends GDTComponent
class_name GDTDebug

var awaiting_integrity_report = false

func _ready() -> void:
	report_ready()

@rpc("any_peer", "reliable")
func receive_data_integrity_test(sha256: String, data: PackedByteArray) -> void:
	var id = multiplayer.get_remote_sender_id()
	print("Receiving test %s byte data from %d" % [data.size(), id])
	
	var real_hash = GDTUtils.sha256_of_buffer(data)
	
	if sha256 == real_hash:
		print("Data integrity OK")
		data_integrity_report.rpc_id(id, true)
	else:
		printerr("Checksum mismatch")
		data_integrity_report.rpc_id(id, false)

@rpc("any_peer", "reliable")
func data_integrity_report(success: bool) -> void:
	if not awaiting_integrity_report:
		return
	
	if success:
		print("Integrity report OK")
	else:
		printerr("Integrity report FAIL")

func send_rpc_integrity_check(id: int, data_len: int) -> void:
	var buf = PackedByteArray()
	var err = buf.resize(data_len)
	
	if err != OK:
		GDTUtils.printerr_stack("Failed to prepare buffer: %s" % error_string(err))
		return
		
	for i in data_len:
		buf[i] = randi_range(0, 225)
	
	var buf_hash = GDTUtils.sha256_of_buffer(buf)
	print("Sending RPC integrity check with buffer length %s bytes" % data_len)
	
	awaiting_integrity_report = true
	receive_data_integrity_test.rpc_id(id, buf_hash, buf)

static func dump_node_classes(root: Node = null, names := []) -> void:
	if not root:
		root = EditorInterface.get_base_control()

	if not root.get_class() in names:
		print(root.get_class())
		names.append(root.get_class())
	
	for i in root.get_children():
		dump_node_classes(i, names)
