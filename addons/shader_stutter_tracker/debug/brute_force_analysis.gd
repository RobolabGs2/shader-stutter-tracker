extends Node

@export var scenes: Array[PackedScene]

var _report_service: SSTReportService
var _settings := SSTPluginSettings.new()
var _triggers_collector: SSTCurrentNodeTriggerCollectorService


static func _prepare_debug_scene(node: Node):
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CanvasLayer or node is CanvasItem or node is Node3D:
		node.visible = false
		if node is VisualInstance3D:
			SSTNodeUtils.disable_culling(node)
	for child in node.get_children():
		_prepare_debug_scene(child)


func _ready() -> void:
	_settings.add_to_project_settings()
	var shader_watcher = SSTShaderWatcher.new(_settings.shader_watcher)
	_triggers_collector = SSTCurrentNodeTriggerCollectorService.new(self)
	_report_service = SSTReportService.new(_settings.report, shader_watcher, _triggers_collector)
	await get_tree().process_frame
	for scene in scenes:
		await _debug_scene(scene)
		await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _process(_delta: float) -> void:
	_report_service.send_report_if_needed(get_viewport())


func _debug_by_node_scene(node: Node):
	if node is CanvasLayer or node is CanvasItem or node is Node3D:
		_triggers_collector.current_node = node
		node.visible = true
		if node is GPUParticles3D or node is CPUParticles3D:
			node.emitting = true
		## wait two ticks because some node's shaders compile on second frame (particles)
		await get_tree().process_frame
		await get_tree().process_frame
	for child in node.get_children():
		await _debug_by_node_scene(child)
	if node is CanvasLayer or node is CanvasItem or node is Node3D:
		node.visible = false


func _debug_scene(scene: PackedScene):
	var scene_root := scene.instantiate()
	_prepare_debug_scene(scene_root)
	add_child(scene_root)
	var old_mode := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSyncMode.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _debug_by_node_scene(scene_root)
	Engine.max_fps = 60
	DisplayServer.window_set_vsync_mode(old_mode)
	remove_child(scene_root)


class SSTCurrentNodeTriggerCollectorService:
	extends SSTReportService.SSTTriggerCollectorService
	var current_node: Node


	func _init(node: Node):
		self.current_node = node


	func collect() -> SSTTriggerCollector:
		var triggers := SSTTriggerCandidate.from_or_unknown(current_node)
		collector.add_new_triggers_force(current_node, triggers)
		return collector
