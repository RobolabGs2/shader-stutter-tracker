class_name SSTTriggerCandidate
extends RefCounted

enum Type {
	NODE,
	RESOURCE,
}

var trigger: Object
var type: Type
var clazz: String
var shaders: Array[StringName]
var path: String
var key: Dictionary
var resources_chain: Array[Resource]


static func from(obj: SSTNodeWrapper) -> Array[SSTTriggerCandidate]:
	var collector := SSTTriggerExtractor.new()
	collector.extract(obj)
	return collector.triggers


static func from_or_unknown(obj: SSTNodeWrapper) -> Array[SSTTriggerCandidate]:
	var triggers := from(obj)
	if not triggers.is_empty():
		return triggers
	@warning_ignore("shadowed_variable")
	var key := { "class": obj.node_class() }
	SSTTriggerExtractor.fill_keys_by_properties(obj, key, StringName(obj.node_class()))
	return [
		SSTTriggerCandidate.new(obj, Type.NODE, obj.node_class(), ["UNKNOWN"], obj.node_path(), key),
	]


@warning_ignore("shadowed_variable")
func _init(
		trigger: Object,
		type: Type,
		clazz: String,
		shaders: Array[StringName],
		path: String,
		key: Dictionary = { "path": path },
		resources_chain: Array[Resource] = [],
):
	self.trigger = trigger
	self.type = type
	self.clazz = clazz
	self.shaders = shaders
	self.path = path
	self.key = key
	self.resources_chain = resources_chain


func to_dict(save_link_to_trigger: bool) -> Dictionary:
	return {
		"trigger": trigger if save_link_to_trigger else null,
		"path": path,
		"type": type,
		"class": clazz,
		"shaders": shaders,
		"resources": resources_chain.map(
			func(e: Resource):
				return { "path": e.resource_path, "class": e.get_class(), "resource": e },
		),
		"keys": key,
	}
