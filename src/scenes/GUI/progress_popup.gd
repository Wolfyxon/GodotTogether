@tool
extends AcceptDialog
class_name GDTProgressPopup

@onready var bar: ProgressBar = $vbox/bar

var _bind_object: Object = null
var _bind_property: String = ""
var _bind_func: Callable

var close_on_max = true
var description = "Please wait..."

func _ready() -> void:
	if self == EditorInterface.get_edited_scene_root():
		return
	
	get_ok_button().hide()
	$vbox/label.text = description

func _process(_delta: float) -> void:
	if self == EditorInterface.get_edited_scene_root():
		return
	
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

func bind_to_http_download(http: HTTPRequest, cancellable := true) -> void:
	close_on_max = false
	
	set_max(http.get_body_size())
	bind_func(http.get_downloaded_bytes)
	
	if cancellable:
		add_cancel_button("Cancel")
		canceled.connect(http.cancel_request)
	
	http.request_completed.connect(_http_complete)

func _http_complete(_res: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	queue_free()

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
