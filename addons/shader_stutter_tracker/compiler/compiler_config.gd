@tool
class_name SSTCompilerConfig
extends Resource

@export var materials: Array[Material]:
	get:
		return get_materials()
	set(value):
		set_materials(value)

@export var environments: Array[Environment]:
	get:
		return get_environments()
	set(value):
		set_environments(value)

@export var nodes: Array[Dictionary]:
	get:
		return get_nodes()
	set(value):
		set_nodes(value)

var _materials: Array[Material] = []
var _environments: Array[Environment] = []
var _nodes: Array[Dictionary] = []


func get_materials() -> Array[Material]:
	return _materials


func set_materials(value: Array[Material]) -> void:
	_materials = value
	emit_changed()


func get_environments() -> Array[Environment]:
	return _environments


func set_environments(value: Array[Environment]) -> void:
	_environments = value
	emit_changed()


func get_nodes() -> Array[Dictionary]:
	return _nodes


func set_nodes(value: Array[Dictionary]) -> void:
	_nodes = value
	emit_changed()

func merge(another: SSTCompilerConfig) -> void:
	_materials.append_array(another.materials)
	_nodes.append_array(another.nodes)
	_environments.append_array(another.environments)
	emit_changed()

func add_triggers(nodes_report: Array):
	for node in nodes_report:
		for trigger in node["triggers"]:
			if trigger["type"] == SSTTriggerCandidate.Type.RESOURCE:
				var path = trigger["path"]
				var resource := load(path)
				if resource is Material:
					_materials.push_back(resource)
				if resource is Shader:
					var shader := resource as Shader
					var mat := ShaderMaterial.new()
					mat.shader = shader
					_materials.push_back(mat)
				if resource is Environment:
					_environments.push_back(resource)
			else:
				_nodes.push_back(node["tree_nodes"].back())
	emit_changed()


func clear():
	_materials.clear()
	_environments.clear()
	_nodes.clear()
	emit_changed()
