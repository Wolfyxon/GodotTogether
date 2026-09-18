@tool
class_name GDTFiles

const ignored_dirs = [
	"res://.godot", 
	"res://.import", 
	"res://.vscode", 
	"res://.idea",
	"res://.github",
	#"res://addons"
]

static func ensure_dir_exists(path: String) -> int:
	var dir = path.get_base_dir()
	
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		return DirAccess.make_dir_recursive_absolute(dir)
		
	return OK

static func has_traversal(path: String) -> bool:
	return path.contains("..")

static func is_path_in_project(path: String) -> bool:
	if not path.begins_with("res://"): return false
	
	return ProjectSettings.globalize_path(path).begins_with(ProjectSettings.globalize_path("res://"))

static func get_file_tree(root := "res://", include_unsafe := false) -> Array[String]:
	if root in ignored_dirs: return []
	var res: Array[String] = []
	
	var dir = DirAccess.open(root)
	
	if not dir:
		GDTUtils.printerr_stack("Unable to open dir: %s" % root)
		return []
	
	for file in dir.get_files():
		var path = root.path_join(file)
		
		if include_unsafe or GDTValidator.is_path_safe(path):
			res.append(path)
	
	for dir_name in dir.get_directories():
		var path = root.path_join(dir_name)
		
		if include_unsafe or GDTValidator.is_path_safe(path):
			var sub = get_file_tree(path, include_unsafe)
			prints(dir_name, sub)
			res.append_array(sub)
	
	return res

static func get_file_tree_hashes(root := "res://") -> Dictionary:
	var res = {}
	
	for path in get_file_tree(root):
		res[path] = FileAccess.get_sha256(path)
	
	return res
