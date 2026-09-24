extends Node
class_name GDTHalloweenEvent

var main: GodotTogether = null

var event_timer = Timer.new()

func _ready() -> void:
	print("It's the spooky season!")
	
	event_timer.wait_time = get_standard_delay()
	event_timer.timeout.connect(random_event)
	add_child(event_timer)
	event_timer.start()
	

func random_event() -> void:
	var funcs = [
		fade_screen,
		spawn_user_3d,
		spawn_eyes,
		play_knocking
	]
	
	funcs.pick_random().call()
	event_timer.wait_time = get_standard_delay()

func get_standard_delay() -> float:
	return randf_range(10, 60 * 2)

func fade_screen() -> void:
	var root = EditorInterface.get_base_control()
	
	var t = root.create_tween()
	t.tween_property(root, "modulate", Color(1, 0.9, 0.9), 0.25)
	t.tween_property(root, "modulate", Color.WHITE, 0.25)

func spawn_eyes() -> void:
	var vp = EditorInterface.get_editor_viewport_2d()
	if not vp: return

	var origin = vp.get_mouse_position()
	
	for i in randi_range(2, 20):
		spawn_eye(origin + Vector2(
				randf_range(-200, 200),
				randf_range(-200, 200),
			)
		)
		
		await get_tree().create_timer(randf_range(0.01, 0.2)).timeout

func spawn_eye(pos: Vector2) -> void:
	var img_open = load("res://addons/GodotTogether/src/img/visible.svg")
	var img_closed = load("res://addons/GodotTogether/src/img/hidden.svg")
	
	var sprite = Sprite2D.new()
	var vp = EditorInterface.get_editor_viewport_2d()
	
	sprite.position = pos
	sprite.modulate = Color.TRANSPARENT
	sprite.texture = img_closed
	vp.add_child(sprite)
	
	var t = sprite.create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	t.tween_property(sprite, "texture", img_open, 0.1)
	t.tween_property(sprite, "texture", img_closed, 1)
	t.tween_property(sprite, "modulate", Color.TRANSPARENT, 0.05)
	t.tween_callback(sprite.queue_free)

func spawn_user_3d() -> void:
	var viewport_3d = EditorInterface.get_editor_viewport_3d()
	if not viewport_3d: return
	
	var cam = viewport_3d.get_camera_3d()
	if not cam: return
	
	var user = GDTUser.new(randi_range(-999, -5))
	user.name = "???"
	user.color = Color.BLACK
	
	var avatar = main.dual.create_avatar_3d(user)
	
	avatar.receive_transform(cam.position + Vector3(
		randf_range(-40, 40),
		randf_range(-40, 40),
		randf_range(-40, 40),
	), -cam.rotation)
	
	await get_tree().create_timer(
		randf_range(5, 10)
	).timeout
	
	main.dual.remove_avatars_of_user(user.id)

func play_knocking() -> void:	
	var paths = [
		"res://addons/GodotTogether/src/scripts/extras/halloween/knock1.ogg",
		"res://addons/GodotTogether/src/scripts/extras/halloween/knock2.ogg",
	]
	
	var audio = AudioStreamPlayer.new()
	audio.stream = load(paths.pick_random())
	audio.volume_db = -5
	audio.pitch_scale = randf_range(0.95, 1.025)
	
	add_child(audio)
	audio.play()
	
	audio.finished.connect(audio.queue_free)
