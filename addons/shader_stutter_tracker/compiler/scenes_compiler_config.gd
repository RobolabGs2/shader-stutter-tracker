@tool
class_name SSTScenesCompilerConfig
extends SSTCompilerConfig

enum SSTExportScanSetting {
	DISABLED,
	BAKE_ON_EXPORT,
	RUNTIME_SCAN,
}
enum SSTEditorScanSetting {
	DISABLED,
	RUNTIME_SCAN,
}

## Scan scenes for exported build
@export var rescan_on_export := SSTExportScanSetting.DISABLED
## Scan scenes for play in editor
@export var rescan_in_editor := SSTEditorScanSetting.DISABLED

@export var scenes: Array[PackedScene]:
	get:
		return _scenes
	set(value):
		_scenes = value
		emit_changed()

var _refreshing := false

var _scenes: Array[PackedScene] = []
var _refreshed := false


static func _extract(node: Node, collector: SSTTriggerCollector):
	collector.add_new_triggers(node, SSTTriggerCandidate.from(node))
	for child in node.get_children(true):
		_extract(child, collector)


func get_materials() -> Array[Material]:
	_lazy_rescan()
	return super.get_materials()


func get_environments() -> Array[Environment]:
	_lazy_rescan()
	return super.get_environments()


func get_nodes() -> Array[Dictionary]:
	_lazy_rescan()
	return super.get_nodes()


func refresh(save = true):
	clear()
	add_from_scenes(scenes)
	emit_changed()
	if save and resource_path != "":
		ResourceSaver.save(self, resource_path)


func add_scenes_from_directory(dir_path: String, recursive: bool):
	scenes.clear()
	var scene_exts := ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	_scan_scenes(dir_path, scene_exts, scenes, recursive)
	emit_changed()


func add_from_scenes(scenes: Array[PackedScene]):
	var collector := SSTTriggerCollector.new()
	var visited_scenes: Dictionary[String, bool] = { }
	for scene in scenes:
		var path := scene.resource_path
		if path != "" and visited_scenes.has(path):
			continue
		visited_scenes.set(path, true)
		_add_from_scene(collector, scene)
		if path == "":
			continue
		SSTResourceUtils.walk_dependencies_graph(
			func(new_path, depth):
				if new_path == path:
					return
				if SSTResourceUtils.is_scene_path(new_path) and not visited_scenes.has(new_path):
					var new_scene = load(new_path)
					if new_scene is not PackedScene:
						return
					_add_from_scene(collector, new_scene),
			path,
		)


func get_scenes_in_folder(folder_path: String, recursive: bool) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var scene_exts := ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	_scan_scenes(folder_path, scene_exts, result, recursive)
	return result


func _add_from_scene(collector: SSTTriggerCollector, scene: PackedScene):
	var root := scene.instantiate()
	_extract(root, collector)
	add_triggers(collector.report())
	collector.clear()
	root.free()


func _scan_scenes(
	folder_path: String,
	scene_exts: Array,
	result: Array[PackedScene],
	recursive: bool,
) -> void:
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path := folder_path.path_join(file_name)
			if recursive and dir.current_is_dir():
				_scan_scenes(full_path, scene_exts, result, recursive)
			else:
				var ext := file_name.get_extension().to_lower()
				if ext in scene_exts:
					var scene := load(full_path)
					if scene is PackedScene:
						result.append(scene)
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_export():
	if rescan_on_export == SSTExportScanSetting.BAKE_ON_EXPORT:
		refresh(false)


func _lazy_rescan():
	if _refreshing or _refreshed:
		return
	var in_editor := Engine.is_editor_hint() or not OS.has_feature("editor")
	if not (
		in_editor and rescan_in_editor == SSTEditorScanSetting.RUNTIME_SCAN
		or (not in_editor) and rescan_on_export == SSTExportScanSetting.RUNTIME_SCAN
	):
		return

	_refreshing = true
	refresh(false)
	_refreshed = true
	_refreshing = false
