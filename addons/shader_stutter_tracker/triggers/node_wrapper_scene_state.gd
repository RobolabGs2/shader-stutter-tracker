class_name SSTSceneStateNodeWrapper
extends SSTNodeWrapper

var children: Dictionary[String, SSTSceneStateNodeWrapper] = { }
var _scene: SceneState
var _idx: int
var _class: StringName
var _properties: Dictionary[StringName, Variant]
var _path: String


## Return tree root
static func build_tree(scene: SceneState) -> SSTSceneStateNodeWrapper:
	var root := SSTSceneStateNodeWrapper.new(scene, 0)
	for idx in range(1, scene.get_node_count()):
		var instance := scene.get_node_instance(idx)
		if instance != null:
			var child := build_tree(instance.get_state())
			child.override_path(scene, idx)
			child.override_properties(scene, idx)
			root.add_child(child._path.split("/").slice(1), child)
			continue
		var path := String(scene.get_node_path(idx).get_concatenated_names()).split("/").slice(1)
		var existed_child: SSTSceneStateNodeWrapper = root.find_child(path)
		if existed_child:
			existed_child.override_path(scene, idx)
			existed_child.override_properties(scene, idx)
			continue
		root.add_child(path, SSTSceneStateNodeWrapper.new(scene, idx))
	return root


func _init(scene: SceneState, idx: int):
	_scene = scene
	_idx = idx
	_class = scene.get_node_type(idx)
	var instance := scene.get_node_instance(idx)
	if instance != null:
		var state := instance.get_state()
		for j in range(state.get_node_property_count(0)):
			_properties[state.get_node_property_name(0, j)] = state.get_node_property_value(0, j)
	for j in range(scene.get_node_property_count(idx)):
		_properties[scene.get_node_property_name(idx, j)] = scene.get_node_property_value(idx, j)
	_path = scene.get_node_path(idx)


func add_child(path: Array[String], child: SSTSceneStateNodeWrapper) -> void:
	var prefix := path[0]
	if path.size() == 1:
		children[prefix] = child
		return
	# Crutch, FIXME
	if not children.has(prefix):
		children["/".join(path)] = child
		return
	children[prefix].add_child(path.slice(1), child)


func find_child(path: Array[String]) -> Variant:
	var prefix := path[0]
	if path.size() == 1:
		return children.get(prefix, null)
	if not children.has(prefix):
		return null
	return children[prefix].find_child(path.slice(1))


func override_properties(scene: SceneState, idx: int):
	for j in range(scene.get_node_property_count(idx)):
		_properties[scene.get_node_property_name(idx, j)] = scene.get_node_property_value(idx, j)


func override_path(scene: SceneState, idx: int):
	_path = scene.get_node_path(idx)


func node_class() -> String:
	return _class


func node_property(name: StringName) -> Variant:
	if _properties.has(name):
		return _properties.get(name)
	return ClassDB.class_get_property_default_value(_class, name)


func node_function(name: StringName, args: Array) -> Variant:
	if name == "get_surface_override_material_count":
		var count := 0
		for property in _properties:
			if property.begins_with("surface_material_override/"):
				count += 1
		return count
	if name == "get_surface_override_material":
		return node_property("surface_material_override/%s" % [",".join(args)])
	return null


func node_path() -> String:
	return _path


func node_copy_properties(dst = { }, type_filter: Array[Variant.Type] = []) -> Variant:
	for property in _properties:
		var value: Variant = _properties[property]
		if typeof(value) in type_filter:
			dst[property] = value
	return dst
