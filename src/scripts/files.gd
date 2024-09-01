class_name GodotTogetherFiles

func get_files(path: String) -> Array[String]:
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

func get_dirs(path: String) -> Array[String]:
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

func get_fs_hash(path := "res://") -> int:
	var res = 0
	
	var dir = DirAccess.open(path)
	assert(dir, "Failed to open " + path)
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			var ignored = false
			# TODO: Check absolute paths
			for ignored_dir in GodotTogether.ignored_dirs:
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
