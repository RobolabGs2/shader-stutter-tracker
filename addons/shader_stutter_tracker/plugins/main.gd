@tool
extends EditorPlugin

const SHADER_WATCHER_AUTOLOAD_NAME = "SSTDebugRuntime"

const DebuggerPlugin := preload("uid://dl1hnuq0wiunt")

var settings := SSTPluginSettings.new()
var context_menu := preload("uid://bbkk2dyrahwf4").new()
var scene_compiler_config_inspector := preload("uid://ccqsrhv7ascmb").new()
var compiler_config_inspector = preload("uid://5ld20u66doj7").new()
var debugger := DebuggerPlugin.new()


func _enter_tree():
	add_debugger_plugin(debugger)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, context_menu)
	add_inspector_plugin(compiler_config_inspector)
	add_inspector_plugin(scene_compiler_config_inspector)


func _exit_tree():
	remove_inspector_plugin(scene_compiler_config_inspector)
	remove_inspector_plugin(compiler_config_inspector)
	remove_context_menu_plugin(context_menu)
	remove_debugger_plugin(debugger)


func _run_scene(scene: String, args: PackedStringArray) -> PackedStringArray:
	if scene != context_menu.running_scene:
		args.append("--enable-sst-autoload")
	return args


func _enable_plugin():
	settings.add_to_project_settings()
	add_autoload_singleton(
		SHADER_WATCHER_AUTOLOAD_NAME,
		"res://addons/shader_stutter_tracker/debug/runtime_autoload.gd",
	)


func _disable_plugin():
	remove_autoload_singleton(SHADER_WATCHER_AUTOLOAD_NAME)
	if not settings.base.preserve_settings.value:
		settings.delete_from_project_settings()
