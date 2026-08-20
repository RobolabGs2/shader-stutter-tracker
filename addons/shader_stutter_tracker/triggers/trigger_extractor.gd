class_name SSTTriggerExtractor
extends RefCounted

static var trigger_properties_by_class: Dictionary[StringName, Array] = { }
static var _prepared := false

var triggers: Array[SSTTriggerCandidate] = []
var savedmats := { }


static func prepare() -> void:
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
		&"Sprite3D": [
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
		if is_nullable:
			key[k] = source.get(k) == null
		else:
			key[k] = source.get(k)


func add(obj: Object):
	var collector := self
	if obj is VisualInstance3D:
		collector.add_from_visual_instance_3d(obj)
	elif obj is GridMap:
		collector.add_from_grid_map(obj)
	elif obj is Environment:
		collector.add_from_environment(obj)
	elif obj is CanvasItem:
		collector.add_from_canvas_item(obj)
	elif obj is Camera3D:
		collector.add_from_environment(obj.environment)
	elif obj is WorldEnvironment:
		collector.add_from_environment(obj.environment)


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


func add_from_grid_map(node: GridMap):
	var lib := node.mesh_library
	add_from_mesh_library(lib)


func add_from_visual_instance_3d(node: VisualInstance3D):
	var path := SSTNodeUtils.get_node_path(node)
	var clazz := node.get_class()
	# Decal: all decals are drowed by one shader, so just ignore it
	if node is Decal:
		triggers.push_back(
			SSTTriggerCandidate.new(
				node,
				SSTTriggerCandidate.Type.NODE,
				clazz,
				[&"Scene"],
				path,
				{ "class": "Decal" },
			),
		)
		return
	# FogVolume
	if node is FogVolume:
		# TODO: check in Mobile/Forward+ RenderingServer.FogVolumeShapeshape
		add_material(node.material)
		return
	# GeometryInstance3D
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		add_material(gi.material_overlay)
		add_material(gi.material_override)
		# CPUParticles3D
		if gi is CPUParticles3D:
			var p := gi as CPUParticles3D
			add_from_mesh(p.mesh)
		# CSGShape3D
		elif gi is CSGShape3D:
			if "material" in gi:
				add_material(gi.material)
			if "mesh" in gi:
				add_from_mesh(gi.mesh)
		# GPUParticles3D
		elif gi is GPUParticles3D:
			var p := gi as GPUParticles3D
			add_material(p.process_material)
			for i in range(0, p.draw_passes):
				add_from_mesh(p.get_draw_pass_mesh(i))
		# MeshInstance3D
		elif gi is MeshInstance3D:
			var m := gi as MeshInstance3D
			for i in range(0, m.get_surface_override_material_count()):
				add_material(m.get_surface_override_material(i))
			add_from_mesh(m.mesh)
			if m.skin != null:
				for t in triggers:
					t.shaders.push_back(&"Skeleton")
		# MultiMeshInstance3D
		elif gi is MultiMeshInstance3D:
			var mm := gi as MultiMeshInstance3D
			if mm.multimesh != null:
				add_from_mesh(mm.multimesh.mesh)
		# Label3D
		elif gi is Label3D:
			var key := { "class": "Label3D" }
			fill_keys_by_properties(node, key, &"Label3D")
			triggers.push_back(
				SSTTriggerCandidate.new(
					node,
					SSTTriggerCandidate.Type.NODE,
					clazz,
					[&"Scene", &"CanvasSdf"],
					path,
					key,
				),
			)
		# SpriteBase3D
		elif gi is SpriteBase3D:
			var key := { "class": gi.get_class() }
			fill_keys_by_properties(node, key, &"SpriteBase3D")
			triggers.push_back(
				SSTTriggerCandidate.new(node, SSTTriggerCandidate.Type.NODE, clazz, [&"Scene"], path, key),
			)
	if node is Light3D:
		if (node as Light3D).editor_only:
			return
		var key := { "class": node.get_class() }
		fill_keys_by_properties(node, key, &"Light3D")
		fill_keys_by_properties(node, key, node.get_class())
		triggers.push_back(
			SSTTriggerCandidate.new(node, SSTTriggerCandidate.Type.NODE, clazz, [&"LIGHT"], path, key),
		)

	# Rest subtypes don't use materials (todo: check)
	# GPUParticlesAttractor3D
	# GPUParticlesCollision3D
	# LightmapGI
	# OccluderInstance3D
	# OpenXRVisibilityMask
	# ReflectionProbe
	# RootMotionView
	# VisibleOnScreenNotifier3D
	# VoxelGI


func add_from_canvas_item(node: CanvasItem):
	add_material(node.material)


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
