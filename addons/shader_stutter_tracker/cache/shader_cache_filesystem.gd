class_name SSTShaderCacheFilesystem

const CACHE_DIR := "user://shader_cache"


## Returns statistics about the number of cached shader files per directory.
static func get_stats() -> Dictionary[String, int]:
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		return { }

	var dirs := DirAccess.get_directories_at(CACHE_DIR)
	var stats: Dictionary[String, int] = { }

	for dir in dirs:
		if not dir.contains("Shader"):
			continue

		var count := 0
		var dir_path := CACHE_DIR + "/" + dir

		for subdir in DirAccess.get_directories_at(dir_path):
			count += DirAccess.get_files_at(dir_path + "/" + subdir).size()

		stats[dir] = count
	return stats


## Clears all files within the shader cache directories.
static func clear_cache() -> void:
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		return

	var dirs := DirAccess.get_directories_at(CACHE_DIR)
	for dir in dirs:
		var dir_path := CACHE_DIR + "/" + dir
		for subdir in DirAccess.get_directories_at(dir_path):
			var subdir_path := dir_path + "/" + subdir
			var d := DirAccess.open(subdir_path)
			if d:
				for file in DirAccess.get_files_at(subdir_path):
					d.remove(file)
