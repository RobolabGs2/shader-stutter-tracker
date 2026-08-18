@tool
extends EditorInspectorPlugin

var _open_file_dialog: EditorFileDialog


func _can_handle(object):
	return object is SSTCompilerConfig

func _parse_property(
	object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags,
	_wide: bool,
):
	if name == "materials":
		add_custom_control(_create_buttons(object))
	return false

func _create_button(text, pressed) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(pressed)
	return b

func _create_buttons(object: Object) -> Control:
	var container := HBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(_create_button("Add from another config", func(): _on_add_from_another(object)))
	return container



func _init_open_file_dialog() -> void:
	if _open_file_dialog == null:
		_open_file_dialog = EditorFileDialog.new()
		_open_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		_open_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		_open_file_dialog.title = "Add triggers from another config"
		_open_file_dialog.add_filter("*.tres", "Godot Resource")
		_open_file_dialog.add_filter("*.res", "Binary Resource")
		EditorInterface.get_base_control().add_child(_open_file_dialog)


func _on_add_from_another(res: SSTCompilerConfig):
	_init_open_file_dialog()
	var binded := _on_file_selected.bind(res)
	if not _open_file_dialog.file_selected.is_connected(binded):
		_open_file_dialog.file_selected.connect(binded, CONNECT_ONE_SHOT)
	_open_file_dialog.popup_file_dialog()


func _on_file_selected(path: String, res: SSTCompilerConfig):
	var another = load(path)
	if another is not SSTCompilerConfig:
		return
	res.merge(another)
	_refresh_ui(res)


func _refresh_ui(res):
	await EditorInterface.get_base_control().get_tree().process_frame
	EditorInterface.inspect_object(null)
	EditorInterface.inspect_object(res)
