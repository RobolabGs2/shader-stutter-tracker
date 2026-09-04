class_name SSTSceneStateNodeWrapper
extends SSTNodeWrapper
var _scene: SceneState
var _idx: int
var _class: StringName
var _properties: Dictionary[StringName, Variant]
var _path: String
func _init(scene: SceneState, idx: int):
	_scene = scene
	_idx = idx
	_class = scene.get_node_type(idx)
	if _class == "":
		var instance := scene.get_node_instance(idx)
		var state := instance.get_state()
		for j in range(state.get_node_property_count(0)):
			_properties[state.get_node_property_name(0, j)] = state.get_node_property_value(0, j)
	for j in range(scene.get_node_property_count(idx)):
		_properties[scene.get_node_property_name(idx, j)] = scene.get_node_property_value(idx, j)
	_path = scene.get_node_path(idx)
func node_class() -> String:
	return _class
func node_property(name: StringName) -> Variant:
	if _properties.has(name):
		return _properties.get(name)
	return ClassDB.class_get_property_default_value(_class, name)
func node_function(name: StringName, args: Array) -> Variant:
	return node_property("%s/%s" % [name, ",".join(args)])
func node_path() -> String:
	return _path
