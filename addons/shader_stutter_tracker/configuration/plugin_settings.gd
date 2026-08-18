class_name SSTPluginSettings
extends RefCounted

const PREFIX := "shader_stutter_tracker/"

var base := SSTBaseSettings.new("")
var shader_watcher := SSTShaderWatcher.SSTShaderWatcherSettings.new("shader_watcher/")
var report := SSTReportService.SSTReportServiceSettings.new("logs/")

var settings: Array[SSTSettingSpec]


func _init():
	settings = _get_settings_list()


func add_to_project_settings():
	for setting in settings:
		setting.add_to_project()
	if Engine.is_editor_hint():
		ProjectSettings.save()


func delete_from_project_settings():
	for setting in settings:
		setting.delete_from_project()
	if Engine.is_editor_hint():
		ProjectSettings.save()


func _get_settings_list() -> Array[SSTSettingSpec]:
	var res: Array[SSTSettingSpec] = []
	for property in get_property_list():
		if property["type"] == TYPE_OBJECT && self[property.name] is SSTSettingSpec.SSTSettingSpecGroup:
			var group := self[property.name] as SSTSettingSpec.SSTSettingSpecGroup
			var prefix := PREFIX + group.group_name
			for p in group.get_property_list():
				if p["type"] == TYPE_OBJECT && group[p.name] is SSTSettingSpec:
					var s := group[p.name] as SSTSettingSpec
					s.prefix = prefix
					res.push_back(s)
	return res


class SSTBaseSettings:
	extends SSTSettingSpec.SSTSettingSpecGroup

	var preserve_settings := SSTSettingSpec.new("preserve_settings_when_disabled", false)
