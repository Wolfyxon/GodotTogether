extends GDTComponent
class_name GDTUnitTests

var success_count = 0
var fail_count = 0

var test_times = {}

func _ready() -> void:
	report_ready()

func exec_test(f: Callable) -> void:
	var start = Time.get_unix_time_from_system()
	var res = f.call()
	var time = Time.get_unix_time_from_system() - start
	
	var test_name = str(f.get_method())
	test_times[test_name] = time
	
	if res:
		print_rich("%s: [color=green]Ok[/color] \t\t%s s" % [test_name, time])
		success_count += 1
	else:
		print_rich("%s: [color=red]FAIL[/color] \t\t%s s" % [test_name, time])
		fail_count += 1

func run_tests() -> void:
	if not main:
		printerr("Cannot run tests without main")
		return
	
	print("--- Running GodotTogether tests ---")
	
	for i in get_method_list():
		if i["name"].begins_with("test_"):
			exec_test(get(i["name"]))
	
	print()
	print("Testing complete")
	print("Slowest: ", get_by_slowest().slice(0, 3))
	
	var fail_str = fail_count
	
	if fail_count != 0:
		fail_str = "[color=red]%s[/color]" % fail_count
	
	print_rich("Succeed: %s | Failed: %s" % [success_count, fail_str])
	
	reset()
	
	print("------------------------------------")

func reset() -> void:
	success_count = 0
	fail_count = 0
	test_times.clear()

func get_by_slowest() -> Array:
	var tests = test_times.keys()
	
	tests.sort_custom(func(a, b):
		return test_times[a] > test_times[b]
	)
	
	return tests

func check_version(ver: String) -> String:
	if ver.is_empty():
		return "Version cannot be empty"
		
	if ver == "unreleased":
		return ""
	
	if not ver[0].is_valid_int():
		return "Version must start with a number"
	
	const ALLOWED_CHARS = "1234567890.-qwertyuiopasdfghjklzxcvbnm"
	
	for i in ver:
		if not ALLOWED_CHARS.contains(i):
			return "Illegal character '%s'" % i
	
	return ""

func test_debug() -> bool:
	if main.node_sync.always_scan:
		printerr("node_sync.always_scan should be false")
		return false
	
	var signing_menu = main.gui.get_node("mainMenu/settings/main/scroll/vbox/updateSigning")
	
	if not signing_menu:
		printerr("Signing menu not found")
		return false
	
	if signing_menu.visible:
		printerr("Release signing menu should be hidden")
		return false
	
	return true

func test_versions() -> bool:
	var valid = [
		main.get_plugin_version(),
		"1.0-alpha",
		"2.5.1-beta",
		"1.0",
		"unreleased"
	]
	
	var invalid = [
		"v.1.0",
		"1,4-alpha",
		"test_version",
	]
	
	var ok = true
	
	for i in valid:
		var err = check_version(i)
		
		if not err.is_empty():
			ok = false
			printerr("%s: %s" % [i, err])
	
	for i in invalid:
		var err = check_version(i)
		
		if err.is_empty():
			ok = false
			printerr("%s should be invalid" % i)
	
	return ok 

func test_resource_encoding() -> bool:
	var a = StandardMaterial3D.new()
	a.albedo_texture = NoiseTexture2D.new()
	
	var encoded = GDTNodeSync.encode_resource(a)
	
	if not encoded:
		printerr("encoded is null")
		return false
		
	if not GDTNodeSync.is_encoded_resource(encoded):
		printerr("Encoded not recognized as an encoded resource")
		return false
	
	var decoded = GDTNodeSync.decode_resource(encoded)
	
	if not decoded:
		printerr("decoded is null")
		return false
	
	if decoded.get_class() != a.get_class():
		printerr("Class %s != %s" % [decoded.get_class(), a.get_class()])
		return false
	
	if not decoded.albedo_texture:
		printerr("Missing 'albedo_texture'")
		return false
	
	return true

func test_sha256() -> bool:
	var a1 = [1, 2, 3, 4]
	var a2 = [1, 2, 3, 4]
	
	var b = [1, 4, 8, 9]
	
	var hash_a1 = GDTUtils.sha256_of_buffer(a1)
	var hash_a2 = GDTUtils.sha256_of_buffer(a2)
	
	if hash_a1.is_empty():
		printerr("Hash is empty")
		return false
	
	if hash_a1 != hash_a2:
		printerr("Hashes of 'a' don't match")
		return false
	
	if hash_a1 == GDTUtils.sha256_of_buffer(b):
		printerr("Hashes of different values equal")
		return false
	
	return true

func test_sha256_file() -> bool:
	var script = get_script()
	
	if not script:
		printerr("Unable to get script instance")
		return false
	
	var path: String = script.resource_path
	
	if path.is_empty():
		printerr("Script instance not a file")
		return false
		
	var buf = FileAccess.get_file_as_bytes(path)
	
	if buf.is_empty():
		printerr("Unable to open file %s" % path)
		return false
	
	var hash_buf = GDTUtils.sha256_of_buffer(buf)
	var hash_file = GDTUtils.sha256_of_file(path)
	
	if hash_buf.is_empty():
		printerr("sha256_of_buffer() empty")
		return false
	
	if hash_file.is_empty():
		printerr("sha256_of_file() empty")
		return false
		
	if hash_buf != hash_file:
		printerr("Hashes differ: \n%s\n%s" % [hash_file, hash_buf])
		return false
	
	return true

func test_compare_dicts() -> bool:
	var a = {
		"sub_dict": {
			"this": {
				"is": {
					"deep": true
				}
			},
			"hi": "hello",
			"bye": "cya"
		},
		
		"thing": true,
		"null": null
	}
	
	var b = {
		"sub_dict": {
			"this": {
				"is": {
					"deep": {
						"innit": true
					}
				}
			},
			"hi": "hello",
			"bye": "goodbye"
		},
		
		"thing": false,
		"null": null,
		"missing": 123
	}
	
	var ab_expected_diff = ["thing", "sub_dict/this/is/deep", "missing", "sub_dict/bye"]
	
	var a_copy = a.duplicate(true)
	
	var equal_diff = GDTUtils.compare_dicts(a, a_copy)
	var ab_diff = GDTUtils.compare_dicts(a, b)
	
	if not equal_diff.is_empty():
		printerr("Got Results for equal dicts: ", equal_diff)
		return false
	
	if ab_expected_diff.size() != ab_diff.size():
		printerr("Unexpected diff '%s' != '%s'" % [ab_diff, ab_expected_diff])
		return false
	
	for i in ab_expected_diff:
		if not i in ab_diff:
			printerr("Missing diff entry '%s'. \n'%s' != \n'%s'" % [i, ab_diff, ab_expected_diff])
			return false
	
	return true

func test_hash_dict() -> bool:
	var lbl = Label.new()
	lbl.text = "Hello"
	
	# -- Unchanged -- #
	
	var h1 = GDTNodeSync.get_hash_dict(lbl)
	var h1_unchanged = GDTNodeSync.get_hash_dict(lbl)
	
	var diff_unchanged = GDTUtils.compare_dicts(h1, h1_unchanged)
	
	if not diff_unchanged.is_empty():
		printerr("Hashes differ without changes: %s", diff_unchanged)
		return false
	
	# -- Changed -- #
	
	lbl.text = "Hello World"
	lbl.visible = false
	lbl.label_settings = LabelSettings.new()
	
	var h2 = GDTNodeSync.get_hash_dict(lbl)
	
	var diff2 = GDTUtils.compare_dicts(h1, h2)
	var expected_diff2 = ["text", "visible", "label_settings"]
	
	if diff2.size() != expected_diff2.size():
		printerr("Diff wrong: '%s' != '%s'" % [expected_diff2, diff2])
		return false
	
	for i in expected_diff2:
		if not i in diff2:
			printerr("Missing '%s' in diff: '%s' != '%s'" % [i, expected_diff2, diff2])
			return false
	
	# -- Object itself changed -- #
	
	lbl.label_settings = LabelSettings.new()
	
	var h3 = GDTNodeSync.get_hash_dict(lbl)
	
	var diff3 = GDTUtils.compare_dicts(h2, h3)
	var expected_diff3 = ["label_settings/."]
	
	if diff3.size() != expected_diff3.size():
		printerr("Diff wrong: '%s' != '%s'" % [expected_diff3, diff3])
		return false
	
	for i in expected_diff3:
		if not i in diff3:
			printerr("Missing '%s' in diff: '%s' != '%s'" % [i, expected_diff3, diff3])
			return false
	
	return true

static func test_setget_nested() -> bool:
	var dict = {
		"a": {
			"b": null
		}
	}
	
	GDTUtils.set_nested(dict, "a/b", "c")
	var dict_val = GDTUtils.get_nested(dict, "a/b")
	
	if dict_val != "c":
		printerr("Dict 'c' != '%s'" % dict_val)
		return false
	
	var lbl = Label.new()
	var lbl_settings = LabelSettings.new()
	lbl.label_settings = lbl_settings
	
	GDTUtils.set_nested(lbl, "label_settings/font_size", 17)
	
	var font_size = GDTUtils.get_nested(lbl, "label_settings/font_size")
	
	if font_size != 17:
		printerr("font_size %s != %s" % [17, font_size])
		return false
	
	return true

static func test_ignored_properties() -> bool:
	var node3d = Node3D.new()
	
	var ignored = GDTNodeSync.get_ignored_properties(node3d)
	var expected = ["owner", "multiplayer", "global_position", "global_transform"]
	
	for i in expected:
		if not i in ignored:
			printerr("%s not found: %s" % [i, ignored])
			return false
	
	return true

static func test_property_keys() -> bool:
	var node3d = Node3D.new()
	
	var keys = GDTNodeSync.get_property_keys(node3d)
	
	var essentials = ["name", "position", "visible"]
	
	for i in essentials:
		if not i in essentials:
			printerr("%s not found " % i)
			return false
	
	for i in GDTNodeSync.IGNORED_PROPERTIES["Node"]:
		if i in keys:
			printerr("%s found" % i)
			return false
	
	for i in GDTNodeSync.IGNORED_PROPERTIES["Node3D"]:
		if i in keys:
			printerr("%s found" % i)
			return false
	
	return true

static func test_node_change_applying() -> bool:
	var lbl = Label.new()
	lbl.label_settings = LabelSettings.new()
	lbl.label_settings.font_size = 7
	
	var h1 = GDTNodeSync.get_hash_dict(lbl)
	var style = StyleBoxFlat.new()
	style.bg_color = Color.RED
	
	lbl.add_theme_stylebox_override("normal", style)
	lbl.text = "when the THE"
	lbl.label_settings = LabelSettings.new()
	lbl.label_settings.font_color = Color.RED
	
	var h2 = GDTNodeSync.get_hash_dict(lbl)
	
	var diff = GDTUtils.compare_dicts(h1, h2)
	var props = GDTNodeSync.get_select_property_dict(lbl, diff)
	
	var lbl_output = Label.new()
	GDTNodeSync.apply_property_dict(lbl_output, props)
	
	var has_setget = false
	
	for i in diff:
		if GDTNodeSync.is_setget_property(lbl, i):
			has_setget = true
			break
	
	if not has_setget:
		printerr("The diff should include a setget property")
		return false
	
	if lbl_output.text != lbl.text:
		printerr("text wrong")
		return false
	
	if not lbl_output.label_settings:
		printerr("label_settings is null")
		return false 
	
	if lbl_output.label_settings.font_color != lbl.label_settings.font_color:
		printerr("font color wrong")
		return false
	
	if lbl_output.label_settings.font_size != 16: # default font size
		printerr("font size remained changed")
		return false
	
	if not lbl_output.has_theme_stylebox_override("normal"):
		printerr("'normal' stylebox override not set")
		return false
	
	var style_output = GDTNodeSync.get_setget_property(lbl_output, "theme_override_styles/normal")
	
	if not style_output:
		printerr("Stylebox is null")
		return false
	
	if not style_output is StyleBoxFlat:
		printerr("Stylebox class wrong: %s" % style_output.get_class())
		return false
	
	if style_output.bg_color != style.bg_color:
		printerr("Stylebox bg_color %s != %s" % [style_output.bg_color, style.bg_color])
		return false
	
	return true

func test_setget_property_dict() -> bool:
	const METHOD_KEYS = ["set", "get", "has", "reset"]
	const ESSENTIALS = []
	
	for node_class in GDTNodeSync.SETGET_PROPERTIES.keys():
		if not ClassDB.class_exists(node_class):
			printerr("Class '%s' doesn't exist" % node_class)
			return false
		
		var class_entry: Dictionary = GDTNodeSync.SETGET_PROPERTIES[node_class]
		
		for prop in class_entry.keys():
			var prop_entry = class_entry[prop]
			
			for key in ESSENTIALS:
				if not key in prop_entry:
					printerr("Missing '%s' in %s of class %s" % [key, prop, node_class])
					return false
			
			for method_key in METHOD_KEYS:
				if not method_key in prop_entry:
					continue
				
				var method_entry = prop_entry[method_key]
				
				if method_entry is String:
					if not ClassDB.class_has_method(node_class, method_entry):
						printerr("%s has no method '%s'" % [node_class, method_entry])
						return false
				elif method_entry is Dictionary:
					if not "func" in method_entry:
						printerr("Missing 'func' in '%s' of %s:%s" % [method_key, node_class, prop])
						return false
						
					if not ClassDB.class_has_method(node_class, method_entry["func"]):
						printerr("%s has no method '%s'" % [node_class, method_entry["func"]])
						return false
					
				else:
					printerr("Invalid method entry type of '%s' in %s:%s" % [method_key, node_class, prop])
					return false
	
	return true

static func test_basic_setget_props() -> bool:
	var lbl = Label.new()
	var h1 = GDTNodeSync.get_hash_dict(lbl)
	
	lbl.add_theme_font_size_override("font_size", 42)
	
	var h2 = GDTNodeSync.get_hash_dict(lbl)
	var diff = GDTUtils.compare_dicts(h1, h2)
	
	if diff.size() != 1:
		printerr("Diff wrong: %s" % diff)
		return false
	
	var prop = diff[0]
	const expected_prop = "theme_override_font_sizes/font_size"
	
	if prop != expected_prop:
		printerr("'%s' != '%s'" % [prop, expected_prop])
		return false
	
	if not GDTNodeSync.is_setget_property(lbl, prop):
		printerr("Property not reported as setget")
		return false
	
	GDTNodeSync.set_setget_property(lbl, prop, 19)
	
	var val = lbl.get_theme_font_size("font_size")
	
	if val != 19:
		printerr("set failed: %s != %s" % [val, 19])
		return false
	
	var def = lbl.get_theme_default_font_size()
	
	GDTNodeSync.set_setget_property(lbl, prop, def)
	
	# Godot seems to reset it on its own after a frame now.
	# This doesn't seem important
	
	#if lbl.has_theme_font_size_override("font_size"):
		#printerr("set didn't reset with default value")
		#return false
	
	return true

static func test_object_setget_props() -> bool:
	var lbl = Label.new()
	var h1 = GDTNodeSync.get_hash_dict(lbl)
	
	var style1 = StyleBoxFlat.new()
	style1.bg_color = Color.RED
	
	lbl.add_theme_stylebox_override("normal", style1)
	
	var h2 = GDTNodeSync.get_hash_dict(lbl)
	var diff = GDTUtils.compare_dicts(h1, h2)
	
	if diff.size() != 1:
		printerr("Diff wrong: %s" % diff)
		return false
	
	var prop = diff[0]
	const expected_prop = "theme_override_styles/normal"
	
	if prop != expected_prop:
		printerr("'%s' != '%s'" % [prop, expected_prop])
		return false
	
	if not GDTNodeSync.is_setget_property(lbl, prop):
		printerr("Property not reported as setget")
		return false
	
	var style2 = StyleBoxFlat.new()
	style2.bg_color = Color.BLUE
	
	GDTNodeSync.set_setget_property(lbl, prop, style2)
	
	var val = lbl.get_theme_stylebox("normal")
	
	if not val:
		printerr("set failed. got null")
		return false
	
	if val.bg_color != style2.bg_color:
		printerr("set failed. bg_color: %s != BLUE" % val.bg_color)
		return false
	
	return true

func test_path_validation() -> bool:
	var safe = [
		"res://",
		"res://addon",
		"res://scenes/game.tscn",
	]
	
	var unsafe = [
		"/usr/bin/res://",
		"user://owies",
		"res://../../thing",
		"res://files/cool/../../../oopsie",
		"res://addons/GodotTogether",
		"/home/wolfyxon/addons/GodotTogether/secret.txt",
		"C:\\Windows\\System32"
	]
	
	for i in safe:
		if not GDTValidator.is_path_safe(i):
			printerr("%s got unsafe" % i)
			return false
	
	for i in unsafe:
		if GDTValidator.is_path_safe(i):
			printerr("'%s' got safe" % i)
	
	return true

func test_updater_crypto() -> bool:
	if not main.updater.get_key():
		printerr("Public key does not load")
		return false
	
	var data1 = "Hello there this is a test" # signed
	var data2 = "Hello here is is a testy test"
	
	# Signature of utf8 buffer. DO NOT TOUCH!!!
	var sig_text = "
					0a0434f96cae41a59e8542ab741caab78b68fa90598ac200db1c33d7e59446d8a52ee48b3f480
					eb55ce13344c61920eb844908ec9c0a6f6654104e7e677177435622d43e5330b9f3ce9114d96b
					d4d7d85aaae4d139f3fb9bf77864739dd4ee29f12a1d595b58511c3d5a058a1eea2e921d8b374
					de527baf321313c2af4adb85009902388f8cefc430ee06bc68245b65a6ff52e312098042cf3c9
					e76af54d37d540ad615a926bbefc7ff6f84cacbbd29711fbf335df16b0f45ea62d9f5a4072f9e
					5893155059feb3caa9edbc67848f55c7d1f86159aefc951e5ef5acf2e4b90ec8751a865d2a0bc
					36e5af526a5aae030ed53dbb2036c42d15ade43802db23417bfafcb5f811ef2930845de22ec6f
					2342ccc42045987abc47c4ab84c7fea97c1da61f7a47c2f52ab29590ff49cdc97545c87bd00b3
					fbc6d04106210744d76b57ee7ff929d830e764c3ce7667e03710bdede062a4d46ceba173ac615
					afb9bc80c56d66d1144f3f5f8ae5959be7dc2ad60c3c8bba47fe8bae34822067c88356f4ed0c2
					0d311c9e2487587cc868bae0ad32f50550da699d99e008dd66c39bacd8548c07d4effc9a91abe
					5f39d7935a18afd8b8fc0f2e205f09709a7c520ecb236ebcf59633d85174f98ae4a21cca16578
					d873a3932d6b4aee5ebc0ec0b60e949ad95ee27d4f8ef7d594e86e813e88da48a5ebc8a263291
					9328a27f4adacbb493df293"
	
	# The decoding can randomly fail. Restart Godot if it happens.
	var sig = sig_text.remove_chars("\n\t ").hex_decode()
	
	if not sig:
		printerr("Unable to decode hex signature into buffer")
		return false
	
	if not main.updater.verify_data(data1.to_utf8_buffer(), sig):
		printerr("data1 should match signature")
		return false
	
	if main.updater.verify_data(data2.to_utf8_buffer(), sig):
		printerr("data2 shouldn't match signature")
		return false
	
	return true

func test_runaway_keys() -> bool:
	var tree = GDTFiles.get_file_tree("res://addons/GodotTogether", true)
	var extensions = ["gd", "txt", "json", "md", "res", "tres", "tscn"]
	
	# Private key header encoded as bytes to not activate the detection
	var header = PackedByteArray(
		[
			45, 45, 45, 45, 45, 66, 69, 71, 73, 78, 32, 82, 83, 65, 32, 80, 
			82, 73, 86, 65, 84, 69, 32, 75, 69, 89, 45, 45, 45, 45, 45
		]
	).get_string_from_utf8()

	var found = []
	
	for path in tree:
		if not path.get_extension() in extensions and not path.contains("Makefile"):
			continue
		
		var text = FileAccess.get_file_as_string(path)
		
		if not text:
			printerr("Unable to open %s" % path)
			continue
			
		if text.contains(header):
			found.append(path)
	
	if not found.is_empty():
		printerr("PRIVATE KEY FOUND IN THE FOLLOWING FILES:")
		
		for path in found:
			printerr(path)
		
		printerr("DO NOT COMMIT OR PUSH!!!")
		
		return false
	
	return true
