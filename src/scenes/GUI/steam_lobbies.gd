@tool
extends VBoxContainer

signal lobby_join_request

@onready var templ = $friend

var main: GodotTogether = null

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	if not main: return
	
	templ.visible = false

func load_lobbies() -> void:
	if not main: return
	
	var lobbies = main.steam.get_friend_lobbies()
	
	clear()
	
	for lobby: Dictionary in lobbies:
		var item = templ.duplicate()
		
		item.get_node("hbox/username").text = lobby["user_name"]
		item.get_node("hbox/btnJoin").pressed.connect(lobby_join_request.emit.bind(lobby["lobby_id"]))
		
		item.visible = true
		add_child(item)

func clear() -> void:
	for i in get_children():
		if i != templ and i is Control:
			i.queue_free()
