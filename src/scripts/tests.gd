extends GDTComponent
class_name GDTUnitTests

var success_count = 0
var fail_count = 0

func exec_test(f: Callable) -> void:
	var res = f.call()
	
	if res:
		print("%s: Ok" % f.get_method())
		success_count += 1
	else:
		print("%s: FAIL" % f.get_method())
		fail_count += 1

func run_tests() -> void:
	if not main:
		printerr("Cannot run tests without main")
		return
	
	print("--- Running GodotTogether tests ---")
	
	exec_test(test_versions)
	exec_test(test_sha256)
	exec_test(test_sha256_file)
	
	print()
	print("Testing complete")
	print("Succeed: %s | Failed: %s" % [success_count, fail_count])
	
	print("------------------------------------")

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
			printerr("%s: %s", i, err)
	
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
