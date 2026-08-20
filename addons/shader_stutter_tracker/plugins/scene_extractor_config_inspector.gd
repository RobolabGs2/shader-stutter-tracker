@tool
extends EditorInspectorPlugin


func _can_handle(object):
	return object is SSTSceneExtractorPrecompilerConfig


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


func _add_scenes_from_directory(res: SSTSceneExtractorPrecompilerConfig) -> void:
	var open_dir_dialog = EditorFileDialog.new()
	open_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	open_dir_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	open_dir_dialog.title = "Add scenes from directory"
	var opt := "Recursive"
	open_dir_dialog.add_option(opt, [], 1)
	EditorInterface.get_base_control().add_child(open_dir_dialog)
	open_dir_dialog.popup_file_dialog()
	open_dir_dialog.dir_selected.connect(
		func(path: String):
			res.add_scenes_from_directory(path, open_dir_dialog.get_selected_options()[opt]),
		CONNECT_ONE_SHOT,
	)
	await open_dir_dialog.dir_selected
	open_dir_dialog.queue_free()


func _create_button(text, pressed) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(pressed)
	return b


func _create_buttons(object: Object) -> Control:
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(
		_create_button(
			"Add scenes from directory",
			func():
				_add_scenes_from_directory(object),
		),
	)
	return container
