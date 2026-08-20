extends EditorContextMenuPlugin


func _popup_menu(paths: PackedStringArray) -> void:
	var scenes: Array[PackedScene] = []
	var has_scenes := false
	for path in paths:
		if SSTResourceUtils.is_scene_path(path):
			has_scenes = true
			break
