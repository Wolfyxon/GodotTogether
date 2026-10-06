extends MultiplayerAPIExtension
class_name GDTMultiplayerExtension

const ROOT_PATH = NodePath("/root")

var main: GodotTogether = null
var base: MultiplayerAPI = null

func _init(_main: GodotTogether, base_api: MultiplayerAPI) -> void:
	if not _main:
		GDTUtils.printerr_stack("main is null")
		return
	
	if not base_api:
		GDTUtils.printerr_stack("base_api is null")
		return
	
	main = _main
	base = base_api
	base.root_path = ROOT_PATH
	
	if base is SceneMultiplayer:
		base.root_path = NodePath("/root")
	
	setup_signals()

func setup_signals() -> void:
	GDTUtils.try_connect_bulk({
		base.connected_to_server: func(): connected_to_server.emit(),
		base.connection_failed: func(): connection_failed.emit(),
		base.server_disconnected: func(): server_disconnected.emit(),
		base.peer_connected: func(id): peer_connected.emit(id),
		base.peer_disconnected: func(id): peer_disconnected.emit(id),
	})

func _rpc(peer: int, object: Object, method: StringName, args: Array) -> Error:
	if main and main.get_settings().get_setting("dev/log_rpc_out"):
		print("Sending RPC to %d: %s::%s(%s)" % [peer, object, method, args])
	
	return base.rpc(peer, object, method, args)

func _poll():
	return base.poll()

func _object_configuration_add(object, config: Variant) -> Error:
	return base.object_configuration_add(object, config)

func _object_configuration_remove(object, config: Variant) -> Error:
	return base.object_configuration_remove(object, config)

func _set_multiplayer_peer(peer: MultiplayerPeer):
	base.multiplayer_peer = peer

func _get_multiplayer_peer() -> MultiplayerPeer:
	return base.multiplayer_peer

func _get_unique_id() -> int:
	return base.get_unique_id()

func _get_remote_sender_id() -> int:
	return base.get_remote_sender_id()

func _get_peer_ids() -> PackedInt32Array:
	return base.get_peers()
