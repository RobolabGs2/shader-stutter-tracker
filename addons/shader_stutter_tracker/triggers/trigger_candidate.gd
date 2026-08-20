class_name SSTTriggerCandidate
extends RefCounted

enum Type {
	NODE,
	RESOURCE,
}

var type: Type
var clazz: String
var shaders: Array[StringName]
var path: String
var key: Dictionary
var resources_chain: Array[Resource]


static func from(obj: Object) -> Array[SSTTriggerCandidate]:
	var collector := SSTTriggerExtractor.new()
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
	return collector.triggers


static func from_or_unknown(obj: Object) -> Array[SSTTriggerCandidate]:
	var triggers := from(obj)
	if not triggers.is_empty():
		return triggers
	if obj is Node:
		var node := obj as Node
		@warning_ignore("shadowed_variable")
		var key := { "class": node.get_class() }
		SSTTriggerExtractor.fill_keys_by_properties(node, key, StringName(node.get_class()))
		return [
			SSTTriggerCandidate.new(Type.NODE, node.get_class(), ["UNKNOWN"], node.get_path(), key),
		]
	return []


@warning_ignore("shadowed_variable")
func _init(
		type: Type,
		clazz: String,
		shaders: Array[StringName],
		path: String,
		key: Dictionary = { "path": path },
		resources_chain: Array[Resource] = [],
):
	self.type = type
	self.clazz = clazz
	self.shaders = shaders
	self.path = path
	self.key = key
	self.resources_chain = resources_chain


func to_dict() -> Dictionary:
	return {
		"path": path,
		"type": type,
		"class": clazz,
		"shaders": shaders,
		"resources": resources_chain.map(
			func(e: Resource):
				return { "path": e.resource_path, "class": e.get_class() },
		),
		"keys": key,
	}
