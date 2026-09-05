@tool
class_name SSTSceneExtractorPrecompilerConfig
extends SSTShaderPrecompilerConfigBase

enum SSTSceneExtractorPrecompilerConfigSetting {
	MANUALLY,
	RUNTIME,
}
enum SSTSceneExtractorPrecompilerConfigMode {
	INSTANTIATE,
	SCENE_STATE,
}

## Scan scenes in runtime
@export var extract_triggers := SSTSceneExtractorPrecompilerConfigSetting.RUNTIME:
	get():
		return _extract_triggers
	set(value):
		_extract_triggers = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
			if value == SSTSceneExtractorPrecompilerConfigSetting.RUNTIME:
				clear()
@export var scenes: Array[PackedScene] = []:
	get:
		return _scenes
	set(value):
		_scenes = value.duplicate()
@export_group("Triggers cache")
@export var materials: Array[Material] = []:
	get:
		return _materials
	set(value):
		_materials = value.duplicate()
@export var environments: Array[Environment] = []:
	get:
		return _environments
	set(value):
		_environments = value.duplicate()
@export var nodes: Array[Dictionary] = []:
	get:
		return _nodes
	set(value):
		_nodes = value.duplicate()
@export var extraction_mode := SSTSceneExtractorPrecompilerConfigMode.SCENE_STATE
@export_tool_button("Update cache", "Reload") var update_cache_action := refresh
@export_tool_button("Clear cache", "Remove") var clear_cache_action := clear

var _extract_triggers := SSTSceneExtractorPrecompilerConfigSetting.RUNTIME
var _refreshing := false
var _scenes: Array[PackedScene] = []
var _refreshed := false
var _materials: Array[Material] = []
var _environments: Array[Environment] = []
var _nodes: Array[Dictionary] = []


static func _extract(node: Node, collector: SSTTriggerExtractor):
	collector.extract(SSTRuntimeNodeWrapper.new(node))
	for child in node.get_children(true):
		_extract(child, collector)


static func _extract_state_wrapper(node: SSTSceneStateNodeWrapper, collector: SSTTriggerExtractor):
	collector.extract(node)
	for child in node.children:
		_extract_state_wrapper(node.children[child], collector)


static func _get_scenes_in_folder(folder_path: String, recursive: bool) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	var scene_exts := ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	_scan_scenes(folder_path, scene_exts, result, recursive)
	return result


static func _scan_scenes(
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


func _validate_property(property: Dictionary) -> void:
	if property.name in ["materials", "environments", "nodes"]:
		property.usage |= PROPERTY_USAGE_READ_ONLY
	if (
			extract_triggers != SSTSceneExtractorPrecompilerConfigSetting.MANUALLY
			and property.name in ["update_cache_action", "clear_cache_action"]
	):
		property.usage = PROPERTY_USAGE_NONE


func get_materials() -> Array[Material]:
	_lazy_rescan()
	return _materials


func get_environments() -> Array[Environment]:
	_lazy_rescan()
	return _environments


func get_nodes() -> Array[Dictionary]:
	_lazy_rescan()
	return _nodes


func clear():
	_materials.clear()
	_environments.clear()
	_nodes.clear()
	notify_property_list_changed()


func refresh(save = true):
	clear()
	_add_from_scenes()
	if save and resource_path != "":
		ResourceSaver.save(self, resource_path)


func add_scenes_from_directory(dir_path: String, recursive: bool):
	var scene_exts := ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	_scan_scenes(dir_path, scene_exts, scenes, recursive)
	notify_property_list_changed()


func _add_from_scenes():
	var collector := SSTTriggerExtractor.new()
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
			func(new_path, _depth):
				if new_path == path:
					return
				if SSTResourceUtils.is_scene_path(new_path) and not visited_scenes.has(new_path):
					visited_scenes.set(new_path, true)
					var new_scene = load(new_path)
					if new_scene is not PackedScene:
						return
					_add_from_scene(collector, new_scene),
			path,
		)


func _add_from_scene(extractor: SSTTriggerExtractor, scene: PackedScene):
	if extraction_mode == SSTSceneExtractorPrecompilerConfigMode.SCENE_STATE:
		var state := scene.get_state()
		var root := SSTSceneStateNodeWrapper.build_tree(state)
		_extract_state_wrapper(root, extractor)
		_add_triggers(extractor.triggers)
		extractor.triggers.clear()
	else:
		var root := scene.instantiate()
		_extract(root, extractor)
		_add_triggers(extractor.triggers)
		extractor.triggers.clear()
		root.free()


func _add_triggers(triggers: Array[SSTTriggerCandidate]):
	for trigger in triggers:
		if trigger.type == SSTTriggerCandidate.Type.RESOURCE:
			var resource: Resource = trigger.trigger
			if resource is Material:
				materials.push_back(resource)
			if resource is Shader:
				var shader := resource as Shader
				var resources: Array = trigger.resources_chain
				if resources.size() > 1:
					@warning_ignore("confusable_local_declaration")
					var mat = resources[resources.size() - 2]
					if mat != null:
						_materials.push_back(mat)
						continue
				var mat := ShaderMaterial.new()
				mat.shader = shader
				_materials.push_back(mat)
			if resource is Environment:
				_environments.push_back(resource)
		else:
			var node: SSTNodeWrapper = trigger.trigger
			_nodes.append(
				{
					&"class": node.node_class(),
					&"properties": node.node_copy_properties({ }, [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]),
				},
			)


func _lazy_rescan():
	if Engine.is_editor_hint():
		return
	if _refreshing or _refreshed:
		return
	if _extract_triggers != SSTSceneExtractorPrecompilerConfigSetting.RUNTIME:
		return

	_refreshing = true
	refresh(false)
	_refreshed = true
	_refreshing = false
