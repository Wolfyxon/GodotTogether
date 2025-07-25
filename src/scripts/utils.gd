class_name GDTUtils

static func get_descendants(node: Node, include_internal := false) -> Array[Node]:
	var res: Array[Node] = []
	
	for i in node.get_children(include_internal):
		if i.get_child_count(include_internal) != 0: res.append_array(get_descendants(i, include_internal))
		res.append(i)
	
	return res
	
static func is_peer_connected(peer: MultiplayerPeer) -> bool:
	return peer.get_connection_status() == peer.CONNECTION_CONNECTED
