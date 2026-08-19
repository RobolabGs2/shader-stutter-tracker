@tool
class_name SSTShaderPrecompilerConfig
extends SSTShaderPrecompilerConfigBase

@export var materials: Array[Material] = []:
	get:
		return get_materials()
	set(value):
		set_materials(value.duplicate())
@export var environments: Array[Environment] = []:
	get:
		return get_environments()
	set(value):
		set_environments(value.duplicate())
## Array of node description in format:
##	{
##		&"class": "class name",
##		&"properties": { &"property_name": property_value}
##	}
@export var nodes: Array[Dictionary] = []:
	get:
		return get_nodes()
	set(value):
		set_nodes(value.duplicate())

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


func merge(another: SSTShaderPrecompilerConfigBase) -> void:
	_materials.append_array(another.get_materials())
	_environments.append_array(another.get_environments())
	_nodes.append_array(another.get_nodes())
	emit_changed()


func clear():
	_materials.clear()
	_environments.clear()
	_nodes.clear()
	emit_changed()
