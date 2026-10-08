extends Node

func _ready():
	print("--- Starting Project Validation ---")
	var has_error = false
	var files = _get_all_files("res://")
	
	for file in files:
		if file.ends_with(".gd"):
			var script = load(file)
			if script == null:
				print("ERROR loading script: ", file)
				has_error = true
		elif file.ends_with(".tscn"):
			var scene = load(file)
			if scene == null:
				print("ERROR loading scene: ", file)
				has_error = true
			else:
				var instance = scene.instantiate()
				if instance == null:
					print("ERROR instantiating scene: ", file)
					has_error = true
				else:
					instance.queue_free()
					
	if not has_error:
		print("--- Validation Complete: No Errors Found ---")
	else:
		print("--- Validation Complete: Errors Found ---")
	get_tree().quit()

func _get_all_files(path: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name != "." and file_name != "..":
				if not file_name.begins_with("."):
					if dir.current_is_dir():
						if file_name != "addons" and file_name != "build":
							files.append_array(_get_all_files(path.path_join(file_name)))
					else:
						files.append(path.path_join(file_name))
			file_name = dir.get_next()
	return files
