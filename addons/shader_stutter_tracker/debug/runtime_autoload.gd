extends Node

var report_service: SSTReportService
var settings := SSTPluginSettings.new()


func _init() -> void:
	settings.add_to_project_settings()
	if (
			"--enable-sst-autoload" not in OS.get_cmdline_args()
			or not settings.shader_watcher.enable.value
	):
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000

	var shader_watcher = SSTShaderWatcher.new(settings.shader_watcher)
	var triggers_collector = SSTFrustumTriggerCollectorService.new(self)
	report_service = SSTReportService.new(settings.report, shader_watcher, triggers_collector)


func _process(_delta: float) -> void:
	report_service.send_report_if_needed(get_viewport())


class SSTFrustumTriggerCollectorService:
	extends SSTReportService.SSTTriggerCollectorService
	var node: Node


	@warning_ignore("shadowed_variable") func _init(node: Node):
		self.node = node


	func collect() -> SSTTriggerCollector:
		collector.add_in_frustum_3d(node.get_tree().root, node.get_viewport().get_camera_3d())
		return collector
