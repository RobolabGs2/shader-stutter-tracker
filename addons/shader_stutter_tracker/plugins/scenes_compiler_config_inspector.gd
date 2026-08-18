@tool
extends EditorInspectorPlugin

var _open_dir_dialog: EditorFileDialog


func _can_handle(object):
	return object is SSTScenesCompilerConfig


func _parse_property(
	object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags,
	_wide: bool,
):
	if name == "scenes":
		add_custom_control(_create_buttons(object))
	return false

func _on_refresh_pressed(res: SSTScenesCompilerConfig):
	res.refresh()
	_refresh_ui(res)

func _create_button(text, pressed) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(pressed)
	return b

func _create_buttons(object: Object) -> Control:
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(_create_button("Rescan scenes", func(): _on_refresh_pressed(object)))
	container.add_child(_create_button("Add from directory", func(): _on_collect_scenes_pressed(object)))
	return container



func _init_open_dir_dialog() -> void:
	if _open_dir_dialog == null:
		_open_dir_dialog = EditorFileDialog.new()
		_open_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		_open_dir_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_open_dir_dialog.title = "Add scenes from directory"
		_open_dir_dialog.add_option("Recursive", [], 1)
		EditorInterface.get_base_control().add_child(_open_dir_dialog)


func _on_collect_scenes_pressed(res: SSTScenesCompilerConfig):
	_init_open_dir_dialog()
	var binded := _on_dir_selected.bind(res)
	if not _open_dir_dialog.dir_selected.is_connected(binded):
		_open_dir_dialog.dir_selected.connect(binded, CONNECT_ONE_SHOT)
	_open_dir_dialog.popup_file_dialog()


func _on_dir_selected(path: String, res: SSTScenesCompilerConfig):
	res.add_scenes_from_directory(path, _open_dir_dialog.get_selected_options()["Recursive"])
	_refresh_ui(res)


func _refresh_ui(res):
	await EditorInterface.get_base_control().get_tree().process_frame
	EditorInterface.inspect_object(null)
	EditorInterface.inspect_object(res)
