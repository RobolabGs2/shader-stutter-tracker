extends SSTTBaseTest

@export var triggers_source: PackedScene
@export var timeout: int = 10


func run(t: GutTest) -> void:
	var config := SSTSceneExtractorPrecompilerConfig.new()
	config.scenes = [triggers_source]
	config.refresh()
	var cache_dict := SSTSettingSpec.SSTDictionarySettingsSource.new(
		{
			"enable": true,
			"clear_cache_on_run": true,
		},
	)
	var cache_settings := SSTShaderWatcher.SSTShaderWatcherSettings.new("", "", cache_dict)
	var camera: Camera3D = t.add_child_autofree(Camera3D.new())
	camera.make_current()
	var cache_watcher := SSTShaderWatcher.new(cache_settings)
	cache_watcher.check()
	var compiler := SSTShaderPrecompiler.new()
	compiler.config = config
	compiler.camera = camera
	compiler.free_after_compilation = false
	t.add_child_autofree(compiler)
	await t.wait_for_signal(compiler.all_shaders_compiled, timeout)
	t.assert_signal_emitted(compiler, "all_shaders_compiled", "Shaders not compiled within %d sec" % timeout)
	await t.wait_idle_frames(2)
	cache_watcher.check()
	t.add_child_autofree(triggers_source.instantiate())
	await t.wait_idle_frames(4)
	var diff := cache_watcher.check()
	t.assert_eq(diff, { }, "Unexpected shaders:\n%s" % diff)
	pass
