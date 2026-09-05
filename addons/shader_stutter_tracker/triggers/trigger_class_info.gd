class_name SSTTriggerClassInfo
extends RefCounted

static var nodes_with_trigger_properties: Dictionary[String, SSTTriggerTypeDescriptor]:
	get():
		if not _prepared:
			prepare()
		return _nodes_with_trigger_propertiestree
static var nodes_triggers_to_parents: Dictionary[StringName, StringName]:
	get():
		if not _prepared:
			prepare()
		return _nodes_triggers_to_parents
static var nodes_triggers_shaders_types: Dictionary[StringName, Array] = { }
static var _trigger_properties_by_class: Dictionary[StringName, Array] = { }
static var _nodes_triggers_to_parents: Dictionary[StringName, StringName] = { }
static var _prepared := false
static var _nodes_with_trigger_propertiestree: Dictionary[String, SSTTriggerTypeDescriptor] = { }


static func prepare() -> void:
	nodes_triggers_shaders_types = {
		&"Label3D": [&"Scene", &"CanvasSdf"] as Array[StringName],
		&"SpriteBase3D": [&"Scene"] as Array[StringName],
		&"Light3D": [&"Light"] as Array[StringName],
	}
	for type in nodes_triggers_shaders_types:
		_nodes_triggers_to_parents[type] = type
		for child in ClassDB.get_inheriters_from_class(type):
			_nodes_triggers_to_parents[child] = type
	_trigger_properties_by_class = {
		&"Label3D": [
			[&"alpha_antialiasing_mode", false],
			[&"alpha_cut", false],
			[&"billboard", false],
			[&"cast_shadow", false],
			[&"double_sided", false],
			[&"fixed_size", false],
			[&"gi_mode", false],
			[&"no_depth_test", false],
			[&"shaded", false],
			[&"texture_filter", false],
		],
		&"SpriteBase3D": [
			[&"alpha_antialiasing_mode", false],
			[&"alpha_cut", false],
			[&"billboard", false],
			[&"double_sided", false],
			[&"fixed_size", false],
			[&"no_depth_test", false],
			[&"shaded", false],
			[&"texture_filter", false],
			[&"transparent", false],
		],
		&"CanvasItemMaterial": [[&"blend_mode", false], [&"light_mode", false]],
	}
	var classes := [&"BaseMaterial3D", &"Light3D", &"Environment", &"CPUParticles3D"]
	classes.append_array(ClassDB.get_inheriters_from_class(&"Light3D"))
	for clazz in classes:
		_trigger_properties_by_class[clazz] = []
		for property in ClassDB.class_get_property_list(clazz, true):
			var type: Variant.Type = property["type"]
			var hint: PropertyHint = property["hint"]
			var name: String = property["name"]
			if ((type == TYPE_BOOL or hint == PROPERTY_HINT_ENUM)):
				_trigger_properties_by_class[clazz].push_back([StringName(name), false])
	_trigger_properties_by_class[&"ParticleProcessMaterial"] = []
	for property in ClassDB.class_get_property_list(&"ParticleProcessMaterial", true):
		var type: Variant.Type = property["type"]
		var hint: PropertyHint = property["hint"]
		var name: String = property["name"]
		var clazz_name: String = property["class_name"]
		if ((type == TYPE_BOOL or hint == PROPERTY_HINT_ENUM)):
			_trigger_properties_by_class[&"ParticleProcessMaterial"].push_back(
				[StringName(name), false],
			)
		elif (clazz_name.contains("Texture")):
			_trigger_properties_by_class[&"ParticleProcessMaterial"].push_back(
				[StringName(name), true],
			)
	_nodes_with_trigger_propertiestree = generate_tree()
	_prepared = true


static func prepare_keys_fallback(clazz: StringName):
	_trigger_properties_by_class[clazz] = []
	for property in ClassDB.class_get_property_list(clazz, true):
		var type: Variant.Type = property["type"]
		var hint: PropertyHint = property["hint"]
		var name: String = property["name"]
		if (
				(type == TYPE_BOOL or hint == PROPERTY_HINT_ENUM)
				and !name.ends_with("_texture_channel")
		):
			_trigger_properties_by_class[clazz].push_back([StringName(name), false])


static func fill_keys_by_properties(source: Object, key: Dictionary, clazz: StringName) -> void:
	if not _prepared:
		prepare()
	if not _trigger_properties_by_class.has(clazz):
		prepare_keys_fallback(clazz)
	for p in _trigger_properties_by_class[clazz]:
		var k = p[0]
		var is_nullable = p[1]
		var value = source.node_property(k) if source is SSTNodeWrapper else source.get(k)
		if is_nullable:
			key[k] = value == null
		else:
			key[k] = value


static func generate_tree() -> Dictionary[String, SSTTriggerTypeDescriptor]:
	var trigger_resources_parents := ["Material", "Mesh", "Shader", "MeshLibrary", "MultiMesh", "Environment"]
	var trigger_resources: Dictionary[String, String] = { }
	for r in trigger_resources_parents:
		trigger_resources.set(r, r)
		for rr in ClassDB.get_inheriters_from_class(r):
			trigger_resources.set(rr, r)
	var trigger_classes: Dictionary[String, SSTTriggerTypeDescriptor] = { }
	for clazz in ClassDB.get_inheriters_from_class("Node"):
		var trigger_descriptor := SSTTriggerTypeDescriptor.new()
		var exclude_inherited := false
		for property in ClassDB.class_get_property_list(clazz, exclude_inherited):
			var name: String = property["name"]
			var clazz_names: PackedStringArray = property["class_name"].split(",")
			for clazz_name in clazz_names:
				if clazz_name in trigger_resources:
					trigger_descriptor.properties.push_back(name)
					break

		for method in ClassDB.class_get_method_list(clazz, exclude_inherited):
			var property = method["return"]
			var name: String = method["name"]
			var clazz_names: PackedStringArray = property["class_name"].split(",")
			if not name.begins_with("get_") or name.substr(4) in trigger_descriptor.properties:
				continue
			for clazz_name in clazz_names:
				if clazz_name in trigger_resources:
					trigger_descriptor.functions.push_back(method)
					break

		if trigger_descriptor.properties.size() > 0:
			trigger_classes[clazz] = trigger_descriptor
	return trigger_classes


class SSTTriggerTypeDescriptor:
	extends RefCounted
	var clazz: String
	var properties: Array[StringName] = []
	var functions: Array = []
