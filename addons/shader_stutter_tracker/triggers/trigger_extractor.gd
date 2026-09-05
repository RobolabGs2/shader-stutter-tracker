class_name SSTTriggerExtractor
extends RefCounted

var triggers: Array[SSTTriggerCandidate] = []
var savedmats := { }


func extract(node: SSTNodeWrapper):
	var clazz := node.node_class()
	if SSTTriggerClassInfo.nodes_with_trigger_properties.has(clazz):
		var descriptor := SSTTriggerClassInfo.nodes_with_trigger_properties[clazz]
		for property in descriptor.properties:
			add_resource(node.node_property(property))
	var c := StringName(clazz)
	if SSTTriggerClassInfo.nodes_triggers_to_parents.has(c):
		var key = { "class": clazz }
		SSTTriggerClassInfo.fill_keys_by_properties(node, key, c)
		var parent := SSTTriggerClassInfo.nodes_triggers_to_parents[c]
		if parent != c:
			SSTTriggerClassInfo.fill_keys_by_properties(node, key, parent)
		triggers.push_back(
			SSTTriggerCandidate.new(
				node,
				SSTTriggerCandidate.Type.NODE,
				clazz,
				SSTTriggerClassInfo.nodes_triggers_shaders_types[parent],
				node.node_path(),
				key,
			),
		)
	if c == &"MeshInstance3D":
		for i in range(0, node.node_function("get_surface_override_material_count", [])):
			add_material(node.node_function("get_surface_override_material", [i]))
		if node.node_property("skin") != null:
			for t in triggers:
				t.shaders.push_back(&"Skeleton")


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
		SSTTriggerClassInfo.fill_keys_by_properties(mat, key, &"CanvasItemMaterial")
	elif mat is BaseMaterial3D:
		shader_types = [&"Scene"]
		SSTTriggerClassInfo.fill_keys_by_properties(mat, key, &"BaseMaterial3D")
	elif mat is FogMaterial:
		shader_types = [&"Sky"]
	elif mat is PanoramaSkyMaterial:
		shader_types = [&"Sky"]
	elif mat is PhysicalSkyMaterial or mat is ProceduralSkyMaterial:
		key["path"] = mat.resource_path
		shader_types = [&"Sky"]
	elif mat is ParticleProcessMaterial:
		shader_types = [&"Particles", &"ParticlesCopy"]
		SSTTriggerClassInfo.fill_keys_by_properties(mat, key, &"ParticleProcessMaterial")
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
	SSTTriggerClassInfo.fill_keys_by_properties(env, key, env.get_class())
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
