@tool
extends EditorContextMenuPlugin

const BRUTE_FORCE_DEBUG = preload("uid://bv3kp7tsv0ml4")
const BruteForceDebug = preload("uid://nbnn1kdbeqk8")

var save_dialog: EditorFileDialog
var running_scene: String = ""
var _resource_to_save: SSTSceneExtractorPrecompilerConfig
var _scene_extensions := ResourceLoader.get_recognized_extensions_for_type("PackedScene")


func _exit_tree() -> void:
	if is_instance_valid(save_dialog):
		if save_dialog.file_selected.is_connected(_on_file_selected):
			save_dialog.file_selected.disconnect(_on_file_selected)
		save_dialog.queue_free()
		save_dialog = null


func _is_scene_path(path: String) -> bool:
	return path.get_extension().to_lower() in _scene_extensions


func _popup_menu(paths):
	var scenes: Array[PackedScene] = []
	var has_scenes := false
	for path in paths:
		if _is_scene_path(path):
			has_scenes = true
			break
	if has_scenes:
		_init_save_dialog()
		add_context_menu_item("SST: Extract shader triggers from scenes...", _extract)
		add_context_menu_item("SST: Brute-force shader triggers analysis...", _bruteforce)


func _bruteforce(paths):
	var tmp := BRUTE_FORCE_DEBUG.instantiate() as BruteForceDebug
	tmp.scenes = _get_scenes(paths)
	var pack := PackedScene.new()
	pack.pack(tmp)
	var tmp_project_dir := "res://.godot/shader_stutter_tracker/tmp"
	DirAccess.make_dir_recursive_absolute(tmp_project_dir)
	var filepath := tmp_project_dir + "/" + "bruteforce.scn"
	ResourceSaver.save(pack, filepath)
	running_scene = filepath
	EditorInterface.play_custom_scene(filepath)
	running_scene = ""


func _get_scenes(paths) -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	for path in paths:
		if not _is_scene_path(path):
			continue
		var scene_path: String = path
		var scene: PackedScene = load(scene_path)
		scenes.push_back(scene)
	return scenes


func _extract(paths):
	var scenes := _get_scenes(paths)
	var res := SSTSceneExtractorPrecompilerConfig.new()
	res.scenes = scenes
	res.refresh()
	_save_to_user_file(res)


func _init_save_dialog() -> void:
	if save_dialog == null:
		save_dialog = EditorFileDialog.new()
		save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		save_dialog.title = "Save SSTScenesCompilerConfig"
		save_dialog.file_selected.connect(_on_file_selected)
		save_dialog.add_filter("*.tres", "Godot Resource")
		save_dialog.add_filter("*.res", "Binary Resource")
		EditorInterface.get_base_control().add_child(save_dialog)


func _save_to_user_file(res: SSTSceneExtractorPrecompilerConfig):
	_resource_to_save = res
	save_dialog.popup_file_dialog()


func _on_file_selected(path: String) -> void:
	_resource_to_save.take_over_path(path)
	ResourceSaver.save(_resource_to_save, path)
