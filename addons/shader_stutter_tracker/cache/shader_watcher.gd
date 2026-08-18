class_name SSTShaderWatcher
extends RefCounted

var state: Dictionary[String, int] = { }
var settings: SSTShaderWatcherSettings


## Calculates the difference between two statistics dictionaries.
static func _diff(
	old: Dictionary[String, int],
	new: Dictionary[String, int],
) -> Dictionary[String, int]:
	var res: Dictionary[String, int] = { }

	# Combine all keys from both dictionaries
	var all_keys := old.keys()
	for key in new.keys():
		if not all_keys.has(key):
			all_keys.append(key)

	for key in all_keys:
		var diff_val: int = new.get_or_add(key, 0) - old.get_or_add(key, 0)
		if diff_val != 0:
			res[key] = diff_val

	return res


func _init(settings: SSTShaderWatcherSettings):
	self.settings = settings
	if settings.clear_cache_on_run.value:
		SSTShaderCacheFilesystem.clear_cache()
	check()


func register_monitor(shader_key: String) -> void:
	var keys := shader_key.split("Shader")
	var name := &"shaders_cache_%s/%s" % [keys[1], keys[0]]
	if not Performance.has_custom_monitor(name):
		Performance.add_custom_monitor(name, get_shaders_count, [shader_key])


## Return new compiled shaders
func check() -> Dictionary[String, int]:
	var new_stats := SSTShaderCacheFilesystem.get_stats()
	if new_stats == state:
		return { }
	var new_shaders := _diff(state, new_stats)
	for key in new_shaders:
		register_monitor(key)
	state = new_stats
	return new_shaders


func get_shaders_count(name: StringName) -> int:
	return state.get(name, 0)


class SSTShaderWatcherSettings:
	extends SSTSettingSpec.SSTSettingSpecGroup
	var enable := SSTSettingSpec.new("enable", false, { "debug": true })
	var clear_cache_on_run := SSTSettingSpec.new("clear_cache_on_run", false, { "debug": true })
