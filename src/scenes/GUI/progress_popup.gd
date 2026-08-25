extends PopupPanel
class_name GDTProgressPopup

var bar: ProgressBar

var _bind_object: Object = null
var _bind_property: String = ""
var _bind_func: Callable

var close_on_max = true

func _init(description: String) -> void:
	min_size = Vector2(500, 150)
	size = min_size
	exclusive = true
	transient = true
	always_on_top = true
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var label = Label.new()
	label.text = description
	
	bar = ProgressBar.new()
	
	vbox.add_child(label)
	vbox.add_child(bar)
	add_child(vbox)
	
	popup_hide.connect(_hidden)

func _process(delta: float) -> void:
	if _bind_object and _bind_property:
		set_value(_bind_object.get(_bind_property))
	
	if _bind_func:
		set_value(_bind_func.call())

func _hidden() -> void:
	popup_centered()

func bind_property(object: Object, path: String) -> void:
	if not path in object:
		printerr("Object %s doesn't have property: %s" % [object, path])
		return

	_bind_object = object
	_bind_property = path

func bind_func(callable: Callable) -> void:
	_bind_func = callable

func bind_to_http_download(http: HTTPRequest) -> void:
	set_max(http.get_body_size())
	bind_func(http.get_downloaded_bytes)
	
	http.request_completed.connect(queue_free)

func set_max(value: float) -> void:
	if value == -1:
		bar.indeterminate = true
	
	bar.max_value = value

func set_value(value: float) -> void:
	bar.value = value
	
	if close_on_max and value >= bar.max_value:
		queue_free()

func step(steps: float = 1.0) -> void:
	set_value(bar.value + steps)
