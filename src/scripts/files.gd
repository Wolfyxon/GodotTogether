class_name GodotTogetherFiles

const ignored_dirs = ["res://.godot", "res://.import", "res://.vscode", "res://addons"]

static func get_file_tree(root := "res://") -> Array[String]:
	if root in ignored_dirs: return []
	
	var res: Array[String] = []
	
	for file in get_files(root):
		res.append(root.path_join(file))
	
	for dir in get_dirs(root):
		for path in get_file_tree(root.path_join(dir)):
			res.append(path)
	
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

static func get_fs_hash(path := "res://") -> int:
	var res = 0
	
	var dir = DirAccess.open(path)
	assert(dir, "Failed to open " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			var ignored = false
			# TODO: Check absolute paths
			for ignored_dir in ignored_dirs:
				if path + ignored_dir == "res://" + ignored_dir:
					ignored = true
					break
			if ignored: 
				file_name = dir.get_next()
				continue
			
			res += get_fs_hash(path + "/" + file_name)
		else:
			var f = FileAccess.open(path + "/" + file_name, FileAccess.READ)
			res += hash(f.get_buffer(f.get_length()))
			f.close()
		
		res += file_name.hash()
		file_name = dir.get_next()
	
	return res
