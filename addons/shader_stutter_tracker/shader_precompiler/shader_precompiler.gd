@icon("res://addons/shader_stutter_tracker/shader_precompiler/icon.svg")
class_name SSTShaderPrecompiler
extends Node3D

signal all_shaders_compiled
@export var config: SSTShaderPrecompilerConfigBase
@export var camera: Camera3D
@export var batch_size: int = 10
@export var free_after_compilation:= true

var ready_triggers: int = 0
var total_triggers: int = 0

var _quad := SSTResourceUtils.make_skinned_quad()
var _stub_texture := GradientTexture1D.new()


func _ready():
	total_triggers = config.get_materials().size() + config.get_environments().size() * 2 + config.get_nodes().size()
	_add_material3d(null)
	_add_canvas_item_material(null)
	for mat in config.get_materials():
		if (
			mat is BaseMaterial3D
			or SSTResourceUtils.is_shader_with_mode(mat, Shader.Mode.MODE_SPATIAL)
		):
			_add_material_with_skeleton3d(mat)
		elif (
			mat is ParticleProcessMaterial
			or SSTResourceUtils.is_shader_with_mode(mat, Shader.Mode.MODE_PARTICLES)
		):
			_add_particles3d(mat)
		elif (
			mat is CanvasItemMaterial
			or SSTResourceUtils.is_shader_with_mode(mat, Shader.Mode.MODE_CANVAS_ITEM)
		):
			_add_canvas_item_material(mat)
		elif (mat is FogMaterial or SSTResourceUtils.is_shader_with_mode(mat, Shader.Mode.MODE_FOG)):
			_add_fog(mat)
		await _check_counter()
	for description in config.get_nodes():
		_add_node(description)
		await _check_counter()
	for env in config.get_environments():
		camera.environment = env
		await get_tree().process_frame
		await get_tree().process_frame
		await _check_counter()
	await get_tree().process_frame
	all_shaders_compiled.emit()
	if free_after_compilation:
		queue_free()

func _check_counter():
	ready_triggers += 1
	if ready_triggers % batch_size == 0:
		await get_tree().process_frame

func _add_node(description: Dictionary) -> Node:
	var node := SSTNodeUtils.create(description)
	SSTNodeUtils.fill_textures(node, _stub_texture)
	add_child(node)
	node.owner = self
	if node is VisualInstance3D:
		SSTNodeUtils.disable_culling(node)
	return node


func _add_canvas_item_material(material: Material) -> Control:
	var item := Panel.new()
	item.size.x = 10
	item.size.y = 10
	item.material = material
	add_child(item)
	item.owner = self
	return item


func _add_fog(material: Material) -> FogVolume:
	var fog := FogVolume.new()
	fog.material = material
	add_child(fog)
	fog.owner = self
	return fog


func _add_material3d(material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _quad
	add_child(instance)
	instance.owner = self
	instance.material_override = material
	SSTNodeUtils.disable_culling(instance)
	return instance


func _add_material_with_skeleton3d(material: Material) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	add_child(skeleton)
	skeleton.owner = self

	var bone := skeleton.add_bone("Bone1")
	skeleton.set_bone_rest(bone, Transform3D.IDENTITY)

	var instance := _add_material3d(material)
	instance.reparent(skeleton)
	instance.skeleton = instance.get_path_to(skeleton)
	instance.skin = skeleton.create_skin_from_rest_transforms()

	return skeleton


func _add_particles3d(mat: Material):
	var particles := GPUParticles3D.new()
	particles.process_material = mat
	add_child(particles)
	particles.owner = self
