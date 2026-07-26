extends GDTComponent
class_name GDTUnitTests

var success_count = 0
var fail_count = 0

var test_times = {}

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
	
	exec_test(test_versions)
	exec_test(test_sha256)
	exec_test(test_sha256_file)
	exec_test(test_compare_dicts)
	exec_test(test_hash_dict)
	exec_test(test_setget_nested)
	exec_test(test_ignored_properties)
	exec_test(test_property_keys)
	exec_test(test_node_change_applying)
	
	print()
	print("Testing complete")
	print("Slowest: ", get_by_slowest().slice(0, 3))
	print("Succeed: %s | Failed: %s" % [success_count, fail_count])
	
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
	
	lbl.text = "when the THE"
	lbl.label_settings = LabelSettings.new()
	lbl.label_settings.font_color = Color.RED
	
	var h2 = GDTNodeSync.get_hash_dict(lbl)
	
	var diff = GDTUtils.compare_dicts(h1, h2)
	var props = GDTNodeSync.get_select_property_dict(lbl, diff)
	
	var lbl_output = Label.new()
	GDTNodeSync.apply_property_dict(lbl_output, props)
	
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
	
	return true
