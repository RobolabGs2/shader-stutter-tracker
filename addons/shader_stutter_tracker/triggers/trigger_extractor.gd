class_name SSTTriggerExtractor
extends RefCounted

static var trigger_properties_by_class: Dictionary[StringName, Array] = { }
static var _prepared := false

var triggers: Array[SSTTriggerCandidate] = []
var savedmats := { }

func extract(node: SSTNodeWrapper):
	if not _prepared:
		prepare()
	var clazz := node.node_class()
	if tree.has(clazz):
		var descriptor := tree[clazz]
		for property in descriptor.properties:
			add_resource(node.node_property(property))
	var c := StringName(clazz)
	if _node_trigger_types.has(c):
		var key = {"class": clazz}
		fill_keys_by_properties(node, key, c)
		var parent := _node_trigger_types[c]
		if parent != c:
			fill_keys_by_properties(node, key, parent)
		triggers.push_back(
			SSTTriggerCandidate.new(
				node,
				SSTTriggerCandidate.Type.NODE,
				clazz,
				_node_trigger_shaders_types[parent],
				node.node_path(),
				key
			),
		)
	if c == &"MeshInstance3D":
		for i in range(0, node.node_function("get_surface_override_material_count", [])):
			add_material(node.node_function("get_surface_override_material", [i]))
		if node.node_property("skin") != null:
			for t in triggers:
				t.shaders.push_back(&"Skeleton")

static var tree: Dictionary[String, SSTTriggerTypeDescriptor] = {}
static var _node_trigger_types: Dictionary[StringName, StringName] = {}
static var _node_trigger_shaders_types: Dictionary[StringName, Array] = {
	&"Label3D": [&"Scene", &"CanvasSdf"] as Array[StringName],
	&"SpriteBase3D": [&"Scene"] as Array[StringName],
	&"Light3D": [&"Light"] as Array[StringName],
}
static func prepare() -> void:
	var original_trigger_types := _node_trigger_types.duplicate()
	for type in _node_trigger_shaders_types:
		_node_trigger_types[type] = type
		for child in ClassDB.get_inheriters_from_class(type):
			_node_trigger_types[child] = type
	trigger_properties_by_class = {
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
		trigger_properties_by_class[clazz] = []
		for property in ClassDB.class_get_property_list(clazz, true):
			var type: Variant.Type = property["type"]
			var hint: PropertyHint = property["hint"]
			var name: String = property["name"]
			if ((type == TYPE_BOOL or hint == PROPERTY_HINT_ENUM)):
				trigger_properties_by_class[clazz].push_back([StringName(name), false])
	trigger_properties_by_class[&"ParticleProcessMaterial"] = []
	for property in ClassDB.class_get_property_list(&"ParticleProcessMaterial", true):
		var type: Variant.Type = property["type"]
		var hint: PropertyHint = property["hint"]
		var name: String = property["name"]
		var clazz_name: String = property["class_name"]
		if ((type == TYPE_BOOL or hint == PROPERTY_HINT_ENUM)):
			trigger_properties_by_class[&"ParticleProcessMaterial"].push_back(
				[StringName(name), false],
			)
		elif (clazz_name.contains("Texture")):
			trigger_properties_by_class[&"ParticleProcessMaterial"].push_back(
				[StringName(name), true],
			)
	tree = generate_tree()
	_prepared = true


static func prepare_keys_fallback(clazz: StringName):
	trigger_properties_by_class[clazz] = []
	for property in ClassDB.class_get_property_list(clazz, true):
		var type: Variant.Type = property["type"]
		var hint: PropertyHint = property["hint"]
		var name: String = property["name"]
		if (
				(type == TYPE_BOOL or hint == PROPERTY_HINT_ENUM)
				and !name.ends_with("_texture_channel")
		):
			trigger_properties_by_class[clazz].push_back([StringName(name), false])

static func fill_keys_by_properties(source: Object, key: Dictionary, clazz: StringName) -> void:
	if not _prepared:
		prepare()
	if not trigger_properties_by_class.has(clazz):
		prepare_keys_fallback(clazz)
	for p in trigger_properties_by_class[clazz]:
		var k = p[0]
		var is_nullable = p[1]
		var value = source.node_property(k) if source is SSTNodeWrapper else source.get(k)
		if is_nullable:
			key[k] = value == null
		else:
			key[k] = value


func add_resource(res: Resource):
	if res is Material:
		add_material(res)
	elif res is Mesh:
		add_from_mesh(res)
	elif res is MeshLibrary:
		add_from_mesh_library(res)
	elif res is MultiMesh:
		add_from_mesh(res.mesh)
	elif res is Environment:
		add_from_environment(res)


func add_material(mat: Material, prev_resources: Array[Resource] = []):
	if mat == null:
		return
	var resources := prev_resources.duplicate()
	resources.push_back(mat)
	add_material(mat.next_pass, resources)
	var key := { "class": mat.get_class() }
	var shader_types: Array[StringName] = []
	if mat is CanvasItemMaterial:
		shader_types = [&"Canvas"]
		fill_keys_by_properties(mat, key, &"CanvasItemMaterial")
	elif mat is BaseMaterial3D:
		shader_types = [&"Scene"]
		fill_keys_by_properties(mat, key, &"BaseMaterial3D")
	elif mat is FogMaterial:
		shader_types = [&"Sky"]
	elif mat is PanoramaSkyMaterial:
		shader_types = [&"Sky"]
	elif mat is PhysicalSkyMaterial or mat is ProceduralSkyMaterial:
		key["path"] = mat.resource_path
		shader_types = [&"Sky"]
	elif mat is ParticleProcessMaterial:
		shader_types = [&"Particles", &"ParticlesCopy"]
		fill_keys_by_properties(mat, key, &"ParticleProcessMaterial")
	elif mat is ShaderMaterial:
		add_shader(mat.shader, resources)
		return
	else:
		key["path"] = mat.resource_path
	var path := mat.resource_path
	if savedmats.has(key):
		return
	savedmats[key] = true
	triggers.push_back(
		SSTTriggerCandidate.new(
			mat,
			SSTTriggerCandidate.Type.RESOURCE,
			mat.get_class(),
			shader_types,
			path,
			key,
			resources,
		),
	)


func add_shader(shader: Shader, prev_resources: Array[Resource] = []):
	var resources := prev_resources.duplicate()
	var path := shader.resource_path
	var code := shader.code
	var mode := shader.get_mode()
	var k := { "class": "Shader", "hash": code.hash(), "mode": mode }
	if savedmats.has(k):
		return
	savedmats[k] = true
	resources.push_back(shader)
	var shader_types = {
		# Mode used to draw all 3D objects.
		Shader.Mode.MODE_SPATIAL: [&"Scene"] as Array[StringName],
		# Mode used to draw all 2D objects.
		Shader.Mode.MODE_CANVAS_ITEM: [&"Canvas"] as Array[StringName],
		# Mode used to calculate particle information on a per-particle basis.
		Shader.Mode.MODE_PARTICLES: [&"Particles", &"ParticlesCopy"] as Array[StringName],
		# Mode used for drawing skies. Only works with shaders attached to Sky objects.
		Shader.Mode.MODE_SKY: [&"Sky"] as Array[StringName],
		# Mode used for setting the color and density of volumetric fog effect.
		Shader.Mode.MODE_FOG: [&"Sky"] as Array[StringName],
	}[mode]
	triggers.push_back(
		SSTTriggerCandidate.new(
			shader,
			SSTTriggerCandidate.Type.RESOURCE,
			shader.get_class(),
			shader_types,
			path,
			k,
			resources,
		),
	)
static func generate_tree() -> Dictionary[String, SSTTriggerTypeDescriptor]:
	var trigger_resources_parents := ["Material", "Mesh", "Shader", "MeshLibrary", "MultiMesh", "Environment"]
	var trigger_resources : Dictionary[String, String] = {}
	for r in trigger_resources_parents:
		trigger_resources.set(r, r)
		for rr in ClassDB.get_inheriters_from_class(r):
			trigger_resources.set(rr, r)
	var trigger_classes : Dictionary[String, SSTTriggerTypeDescriptor] = {}
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

func add_from_scene_state_node(scene_state: SceneState, idx: int):
	var wrapper := SSTSceneStateNodeWrapper.new(scene_state, idx)
	for property in tree.get(wrapper.node_class(), {"properties": []})["properties"]:
		var value = wrapper.node_property(property)
		add_resource(value)

func add_from_mesh(mesh: Mesh, resources: Array[Resource] = []):
	if mesh == null:
		return
	if mesh is ArrayMesh:
		pass
	resources.push_back(mesh)
	for s in range(mesh.get_surface_count()):
		add_material(mesh.surface_get_material(s), resources)
	if mesh is PrimitiveMesh:
		var p := mesh as PrimitiveMesh
		add_material(p.material, resources)
	resources.pop_back()


func add_from_mesh_library(lib: MeshLibrary):
	for id in lib.get_item_list():
		var mesh := lib.get_item_mesh(id)
		add_from_mesh(mesh, [lib])


func add_from_environment(env: Environment):
	if env == null:
		return
	var prev_resources: Array[Resource] = [env]
	var shader_types: Array[StringName] = []
	var key := { "class": env.get_class() }
	fill_keys_by_properties(env, key, env.get_class())
	if env.background_mode in [
		Environment.BGMode.BG_CLEAR_COLOR,
		Environment.BGMode.BG_COLOR,
		Environment.BGMode.BG_SKY,
	]:
		shader_types.push_back(&"Sky")
	if env.background_mode == Environment.BGMode.BG_SKY:
		if env.sky:
			add_material(env.sky.sky_material, prev_resources)
	if (env.fog_enabled or env.volumetric_fog_enabled) and &"Sky" not in shader_types:
		shader_types.push_back(&"Sky")
	if env.adjustment_enabled:
		shader_types.push_back(&"Post")
	if env.glow_enabled:
		shader_types.push_back(&"Glow")
	if shader_types.size() != 0:
		triggers.push_back(
			SSTTriggerCandidate.new(
				env,
				SSTTriggerCandidate.Type.RESOURCE,
				env.get_class(),
				shader_types,
				env.resource_path,
				key,
				prev_resources,
			),
		)
