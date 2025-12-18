@tool
class_name GDTFiles

const ignored_dirs = [
	"res://.godot", 
	"res://.import", 
	"res://.vscode", 
	"res://.idea",
	"res://.github",
	"res://addons"
]

static func ensure_dir_exists(path: String) -> void:
	var dir = path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

static func is_path_in_project(path: String) -> bool:
	if not path.begins_with("res://"): return false
	
	return ProjectSettings.globalize_path(path).begins_with(ProjectSettings.globalize_path("res://"))

static func get_file_tree(root := "res://") -> Array[String]:
	if root in ignored_dirs: return []
	
	var res: Array[String] = []
	
	for file in get_files(root):
		res.append(root.path_join(file))
	
	for dir in get_dirs(root):
		for path in get_file_tree(root.path_join(dir)):
			res.append(path)
	
	return res

static func get_file_tree_hashes(root := "res://") -> Dictionary:
	var res = {}
	
	for path in get_file_tree():
		var f = FileAccess.open(path, FileAccess.READ)
		res[path] = f.get_as_text().sha256_text()
		f.close()
	
	return res

static func get_files(path: String) -> Array[String]:
	var res: Array[String] = []
	
	var dir = DirAccess.open(path)
	assert(dir, "Failed to open " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if !dir.current_is_dir():
			res.append(file_name)
		
		file_name = dir.get_next()
		
	return res

static func get_dirs(path: String) -> Array[String]:
	var res: Array[String] = []
	
	var dir = DirAccess.open(path)
	assert(dir, "Failed to open " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			res.append(file_name)
		
		file_name = dir.get_next()
		
	return res
