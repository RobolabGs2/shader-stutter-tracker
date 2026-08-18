class_name SSTReportService
extends RefCounted

const PLUGIN_DATA_DIR := "user://shader_stutter_tracker"
const ACTIVE_LOGS_SUBDIR := "logs"

var settings: SSTReportServiceSettings
var collector_service: SSTTriggerCollectorService
var shader_watcher: SSTShaderWatcher


func _init(
	settings: SSTReportServiceSettings,
	shader_watcher: SSTShaderWatcher,
	collector_service: SSTTriggerCollectorService,
):
	self.settings = settings
	self.shader_watcher = shader_watcher
	self.collector_service = collector_service
	logs_rotation()


func logs_rotation():
	DirAccess.make_dir_recursive_absolute(PLUGIN_DATA_DIR)
	var oldest_logs := ""
	var logs_count := 0
	var current_time := Time.get_datetime_string_from_system().replace(":", ".")
	var root := DirAccess.open(PLUGIN_DATA_DIR)
	if root.dir_exists(ACTIVE_LOGS_SUBDIR):
		root.rename(ACTIVE_LOGS_SUBDIR, "%s_%s" % [ACTIVE_LOGS_SUBDIR, current_time])
	var max_logs: int = settings.preserve_last_n_logs.value
	var logs := Array(root.get_directories()).filter(
		func(s: String):
			return s.begins_with(ACTIVE_LOGS_SUBDIR),
	)
	if max_logs >= 0 && max_logs < logs.size():
		for dir in logs.slice(max_logs):
			root.remove(dir)
	root.make_dir(ACTIVE_LOGS_SUBDIR)


func send_report_if_needed(viewport: Viewport):
	var new_shaders := shader_watcher.check()
	if new_shaders.size() == 0:
		return
	var frame_number := Engine.get_process_frames()

	var report := { "frame": { "number": frame_number }, "new_shaders": new_shaders }
	if settings.save_screenshots.value:
		report["frame"]["screenshot"] = viewport.get_texture().get_image().save_png_to_buffer()
	if settings.scan_triggers.value:
		var triggers_collector := collector_service.collect()
		report["nodes"] = triggers_collector.report()
		var saved: bool = settings.save_scenes.value and settings.scan_triggers.value
		if saved:
			var packed_scene := triggers_collector.copy_as_scene()
			var scene_path := PLUGIN_DATA_DIR.path_join(ACTIVE_LOGS_SUBDIR).path_join(
				"%d.tscn" % frame_number
			)
			saved = ResourceSaver.save(packed_scene, scene_path) == Error.OK
			report["frame"]["scene_path"] = scene_path
			report["frame"]["scene_saved"] = saved

	collector_service.clear()
	EngineDebugger.send_message("shader_stutter_tracker:stutter_event", [report])


class SSTReportServiceSettings:
	extends SSTSettingSpec.SSTSettingSpecGroup
	var scan_triggers := SSTSettingSpec.new("scan_triggers", false, { "debug": true })
	var save_screenshots := SSTSettingSpec.new("take_screenshots", false, { "debug": true })
	var save_scenes := SSTSettingSpec.new("save_scenes", false, { "debug": true })
	var preserve_last_n_logs := SSTSettingSpec.new("preserve_last_logs", 3)


@abstract class SSTTriggerCollectorService:
	var collector := SSTTriggerCollector.new()


	@abstract func collect() -> SSTTriggerCollector


	func clear() -> void:
		collector.clear()
