class_name SSTSettingSpec
extends RefCounted

var source: SSTSettingsSource
var prefix: StringName = ""
var name: StringName
var default: Variant
var hint: PropertyHint
var hint_string: String
var basic: bool
var overrides: Dictionary[String, Variant]
var full_name: String:
	get:
		return prefix + name
var value:
	get():
		return source.get_setting_or_default(full_name, default)
	set(val):
		source.set_setting(full_name, value)
var property_info: Dictionary:
	get():
		return {
			"name": full_name,
			"type": typeof(default),
			"hint": hint,
			"hint_string": hint_string,
		}


@warning_ignore("shadowed_variable")
static func _register_setting(
		name: StringName,
		default: Variant,
		property_info: Dictionary,
		basic: bool,
) -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default)
		if Engine.is_editor_hint():
			ProjectSettings.add_property_info(property_info)
	if Engine.is_editor_hint():
		ProjectSettings.set_initial_value(name, default)
		ProjectSettings.set_as_basic(name, basic)


@warning_ignore("shadowed_variable")
func _init(
		name: StringName,
		default: Variant,
		overrides: Dictionary[String, Variant] = { },
		hint: PropertyHint = PropertyHint.PROPERTY_HINT_NONE,
		hint_string: String = "",
		basic: bool = true,
) -> void:
	self.name = name
	self.default = default
	self.basic = basic
	self.hint = hint
	self.hint_string = hint_string
	self.overrides = overrides


func add_to_project() -> void:
	_register_setting(full_name, default, property_info, basic)
	for override in overrides:
		var override_name := full_name + "." + override
		var override_value: Variant = overrides[override]
		var override_info := property_info.duplicate()
		override_info["name"] = name
		_register_setting(override_name, override_value, override_info, basic)


func delete_from_project():
	if ProjectSettings.has_setting(full_name):
		ProjectSettings.set_setting(full_name, null)
	for override in overrides:
		var override_name := full_name + "." + override
		if ProjectSettings.has_setting(override_name):
			ProjectSettings.set_setting(override_name, null)


class SSTSettingSpecGroup:
	var group_name: String


	func _init(name: String, prefix: String, source: SSTSettingsSource):
		group_name = name
		for s in get_settings_list():
			s.source = source
			s.prefix = prefix + name


	func get_settings_list() -> Array[SSTSettingSpec]:
		var res: Array[SSTSettingSpec] = []
		for p in get_property_list():
			if p["type"] == TYPE_OBJECT && self[p.name] is SSTSettingSpec:
				var s := self[p.name] as SSTSettingSpec
				res.push_back(s)
		return res


@abstract class SSTSettingsSource:
	@abstract func get_setting_or_default(name: StringName, default: Variant) -> Variant


	@abstract func set_setting(name: StringName, value: Variant) -> void


class SSTProjectSettingsSource:
	extends SSTSettingsSource
	func get_setting_or_default(name: StringName, default: Variant) -> Variant:
		if ProjectSettings.has_setting(name):
			return ProjectSettings.get_setting_with_override(name)
		return default


	func set_setting(name: StringName, value: Variant) -> void:
		ProjectSettings.set_setting(name, value)


class SSTDictionarySettingsSource:
	extends SSTSettingsSource
	var source := { }


	func _init(settings: Dictionary):
		self.source = settings


	func get_setting_or_default(name: StringName, default: Variant) -> Variant:
		return source.get(name, default)


	func set_setting(name: StringName, value: Variant) -> void:
		source.set(name, value)
