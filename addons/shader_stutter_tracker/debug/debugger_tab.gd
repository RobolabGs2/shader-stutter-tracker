@tool
extends Container

enum SSTCellType {
	FRAME,
	TRIGGER,
	NODE,
	RESOURCE,
}

var frames: Array[Dictionary] = []

var _tree_item_scene: Node

@onready var frames_tree: Tree = %Frames
@onready var trigger_tree: Tree = %TriggerInfo
@onready var save_file_dialog: FileDialog = $SaveFileDialog
@onready var meta_display: RichTextLabel = %MetaDisplay


func _init() -> void:
	pass


func _ready() -> void:
	clear()
	frames_tree.item_selected.connect(_on_frames_tree_item_selected)
	frames_tree.button_clicked.connect(_on_frames_tree_button_clicked)
	trigger_tree.item_selected.connect(_on_trigger_tree_item_selected)
	trigger_tree.button_clicked.connect(_on_trigger_tree_button_clicked)


func _exit_tree() -> void:
	if _tree_item_scene:
		_tree_item_scene.free()
		_tree_item_scene = null


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var e := event as InputEventKey
		if e.keycode == KEY_SLASH and e.alt_pressed:
			redraw()


func add_frame(report: Dictionary):
	frames.push_back(report)
	draw_frame(report)


func save_resources(file: String):
	var res := SSTCompilerConfig.new()
	for frame in frames:
		res.add_triggers(frame["nodes"])
	res.take_over_path(file)
	ResourceSaver.save(res, file)


func draw_frame(report: Dictionary):
	var frame_number: int = report["frame"]["number"]
	var frame_scene_path: String = report["frame"].get("scene_path", "")
	var frame_scene_saved: bool = report["frame"].get("scene_saved", false)
	var maybe_screenshot = report["frame"].get("screenshot", null)
	var frame_node := frames_tree.get_root().create_child()
	frame_node.set_text(0, "frame #%d" % frame_number)
	frame_node.set_metadata(0, SSTCellMetadata.new(SSTCellType.FRAME, report))
	if maybe_screenshot != null:
		var image := Image.new()
		image.load_png_from_buffer(maybe_screenshot)
		var tex := ImageTexture.new()
		tex.set_image(image)
		var screenshot_cell := frame_node #.create_child()
		#screenshot_cell.set_cell_mode(0, TreeItem.CELL_MODE_ICON)
		screenshot_cell.set_icon(0, tex)
		screenshot_cell.set_icon_max_width(0, 256)
	if frame_scene_saved:
		var tmp_project_dir := "res://.godot/shader_stutter_tracker/frames"
		DirAccess.make_dir_recursive_absolute(tmp_project_dir)
		var tmp_scene_dir := tmp_project_dir.path_join("frame_%d.tscn" % frame_number)
		report["frame"]["debug_scene_path"] = tmp_scene_dir
		DirAccess.copy_absolute(frame_scene_path, tmp_scene_dir)
		frame_node.add_button(0, get_icon("InstanceOptions"), 2, false, frame_scene_path)
	var shaders_node := frame_node.create_child()
	var new_shaders: Dictionary = report["new_shaders"]
	var shaders_count := 0
	for shader in new_shaders:
		var item := shaders_node.create_child()
		var count: int = new_shaders[shader]
		var name_parts: Array = shader.split("Shader")
		item.set_text(0, "%s: %d" % [name_parts[0], count])
		shaders_count += count
	shaders_node.set_text(0, "Shaders: %d" % shaders_count)

	var triggers_node := frame_node.create_child()
	var nodes: Array = report.get("nodes", [])
	var node_items: Dictionary[String, TreeItem] = { }
	var triggers_count := 0
	for node in nodes:
		var branch: Array[Dictionary] = node["tree_nodes"]
		var last_item: TreeItem = triggers_node
		for trigger in node["triggers"]:
			var trigger_item := last_item.create_child()
			trigger_item.set_metadata(
				0,
				SSTCellMetadata.new(SSTCellType.TRIGGER, report, { "node": node, "trigger": trigger }),
			)
			var path: String = "%s" % trigger["path"]
			var parts := path.split("/")
			var last := parts.get(parts.size() - 1)
			trigger_item.set_text(0, last)
			var icon := get_icon(trigger["class"])
			trigger_item.set_icon(0, icon)
			triggers_count += 1
			trigger_item.set_text(1, ", ".join(trigger["shaders"]))
	triggers_node.set_text(0, "Trigger candidates: %d" % triggers_count)


func clear():
	frames.clear()
	clear_view()


func redraw():
	clear_view()
	for frame in frames:
		draw_frame(frame)


func clear_view():
	frames_tree.clear()
	frames_tree.create_item()
	trigger_tree.clear()


func get_icon(name: String) -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon(name, "EditorIcons")


func inherited_from(clazz: StringName, child: StringName):
	if clazz == &"Object":
		return true
	while child != &"Object":
		if child == clazz:
			return true
		child = ClassDB.get_parent_class(child)
	return false


func get_or_load_scene(scene_path: String) -> Node:
	if _tree_item_scene != null:
		if _tree_item_scene.scene_file_path == scene_path:
			return _tree_item_scene
		_tree_item_scene.queue_free()
		_tree_item_scene = null
	_tree_item_scene = (load(scene_path) as PackedScene).instantiate()
	return _tree_item_scene


func show_meta(meta):
	return
	if not meta:
		return
	meta_display.text = "%s" % meta.data


func _on_frames_tree_item_selected():
	var selected_item := frames_tree.get_next_selected(null)
	if selected_item == null:
		return
	var meta_raw = selected_item.get_metadata(0)
	if meta_raw == null:
		return
	show_meta(meta_raw)
	var meta := meta_raw as SSTCellMetadata
	if meta.type != SSTCellType.TRIGGER:
		return
	var node: Dictionary = meta.data["node"]
	var trigger: Dictionary = meta.data["trigger"]
	var branch: Array[Dictionary] = node["tree_nodes"]
	trigger_tree.clear()
	var last_node: TreeItem
	for n in branch:
		var path: NodePath = n[&"path"]
		var item := trigger_tree.create_item() if last_node == null else last_node.create_child()
		var cl = n[&"class"]
		item.set_icon(0, get_icon(cl))
		item.set_metadata(0, meta.fork(SSTCellType.NODE, n))
		var name: String = path.get_name(path.get_name_count() - 1)
		last_node = item
		var script = n.get(&"script", null)
		var scene = n.get(&"scene", null)
		var owner = n.get(&"owner", null)
		var tooltip_parts := [name, "Type: %s" % [cl]]
		if scene:
			tooltip_parts.push_back("Instance: %s" % scene)
			item.add_button(0, get_icon("InstanceOptions"), 2, false, "Open scene %s" % scene)

		if script:
			tooltip_parts.push_back("Script: %s" % script)
			item.add_button(0, get_icon("Script"), 1, false, "Open script %s" % script)

		if owner:
			tooltip_parts.push_back("Owner: %s" % owner)

		item.set_text(0, "%s" % [name])
		item.set_tooltip_text(0, "\n".join(tooltip_parts))
	for t in node["triggers"]:
		var resources_chain: Array = t["resources"]
		var last_item := last_node
		for r in resources_chain:
			var path: String = r["path"]
			var item := last_item.create_child()
			var cl = r["class"]
			item.set_icon(0, get_icon(cl))
			item.set_metadata(0, meta.fork(SSTCellType.RESOURCE, r))
			var parts := path.split("/")
			var last := parts.get(parts.size() - 1)
			var name: String = "%s" % last
			if name == "":
				name = "(runtime generated)"
			last_item = item
			var tooltip_parts := [name, "Type: %s" % [cl]]

			if path:
				item.add_button(0, get_icon("FolderBrowse"), 4, false, "Select in FileSystem Dock")
			if inherited_from(&"Material", cl) or cl == &"Shader":
				item.add_button(0, get_icon("Shader"), 5, false, "Open generated shader info")
			item.set_text(0, "%s" % [name])
			item.set_tooltip_text(0, "\n".join(tooltip_parts))


func _on_frames_tree_button_clicked(
	item: TreeItem,
	_column: int,
	id: int,
	_mouse_button_index: int,
):
	var meta_raw = item.get_metadata(0)
	if meta_raw == null:
		return
	var meta := meta_raw as SSTCellMetadata
	if id == 2:
		var tmp_scene_dir = meta.data["frame"]["debug_scene_path"]
		EditorInterface.open_scene_from_path(tmp_scene_dir)


func _on_trigger_tree_item_selected() -> void:
	var selected_item := trigger_tree.get_next_selected(null)
	if selected_item == null:
		return
	var meta_raw = selected_item.get_metadata(0)
	if meta_raw == null:
		return
	show_meta(meta_raw)
	var meta := meta_raw as SSTCellMetadata
	var scene := get_or_load_scene(meta.full_report["frame"]["scene_path"])
	if meta.type == SSTCellType.NODE:
		var node := scene.get_node_or_null((meta.data["path"] as NodePath).slice(1))
		node.set_meta("TEST_META", meta.data)
		EditorInterface.get_inspector().edit(node)
	if meta.type == SSTCellType.RESOURCE:
		var path = meta.data["path"]
		EditorInterface.edit_resource(load(path))


func _on_trigger_tree_button_clicked(
	item: TreeItem,
	_column: int,
	id: int,
	_mouse_button_index: int,
) -> void:
	var meta_raw = item.get_metadata(0)
	if meta_raw == null:
		return
	var meta := meta_raw as SSTCellMetadata
	#if meta.type != SSTCellType.NODE:
	#return
	if id == 1:
		var path = meta.data["script"]
		var script = load(path) as Script
		EditorInterface.edit_resource(script)
	elif id == 2:
		var path = meta.data["scene"]
		EditorInterface.open_scene_from_path(path)
	elif id == 3: # resource
		var path = meta.data["path"]
		EditorInterface.edit_resource(load(path))
	elif id == 4: # resource
		var path = meta.data["path"]
		var parts = path.split("::")
		EditorInterface.get_file_system_dock().navigate_to_path(parts[0])
	elif id == 5:
		var path = meta.data["path"]
		load(path).inspect_native_shader_code()


class SSTCellMetadata:
	var type: SSTCellType
	var frame_number: int
	var full_report: Dictionary
	var data: Dictionary


	func _init(type: SSTCellType, report: Dictionary, data: Dictionary = report):
		self.type = type
		self.frame_number = report["frame"]["number"]
		self.full_report = report
		self.data = data


	func fork(type: SSTCellType, data: Dictionary = self.full_report):
		return SSTCellMetadata.new(type, full_report, data)
