class_name SSTNodeUtils
extends Object


static func create(description: Dictionary) -> Node:
	var clazz: StringName = description[&"class"]
	var properties: Dictionary = description[&"properties"]
	var node := ClassDB.instantiate(clazz)
	for property in properties:
		node.set(property, properties.get(property))
	return node


static func fill_textures(node: Node, texture: Texture) -> void:
	for p in node.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		if not p.class_name.contains("Texture"):
			continue
		var name = p.name
		node.set(name, texture)


static func get_node_path(node: Node) -> NodePath:
	if node.is_inside_tree():
		return node.get_path()
	return _extract_path(node)


static func get_description(node: Node) -> Dictionary:
	var owner := node.owner
	var original_scene := node.scene_file_path
	var owner_path := get_node_path(owner) if owner != null else null
	var path := get_node_path(node)
	var clazz := node.get_class()
	var script := node.get_script()
	var script_path := (script as Script).resource_path if script != null else null
	return {
		&"owner": owner_path,
		&"path": path,
		&"scene": original_scene,
		&"class": clazz,
		&"script": script_path,
		&"properties": copy_properties(node, { }, [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]),
	}


static func owners_chain(node: Node, arr: Array[Dictionary] = []) -> Array[Dictionary]:
	if node.get_parent() != null:
		owners_chain(node.get_parent(), arr)
	arr.push_back(get_description(node))
	return arr


static func copy_recursive(
		source_node: Node,
		destination_node: Node,
		destination_scene_root: Node,
) -> void:
	var dst := clone_node_shallow(source_node)
	dst.name = get_node_path(source_node).get_concatenated_names().replace("/", "_")
	destination_node.add_child(dst)
	dst.owner = destination_scene_root
	if dst is Node3D:
		(dst as Node3D).global_transform = (source_node as Node3D).global_transform
	elif dst is Node2D:
		(dst as Node2D).global_transform = (source_node as Node2D).global_transform


static func copy_from_root(source_node: Node, destination_scene_root: Node) -> Node:
	if source_node.get_parent() == null:
		return destination_scene_root
	var parent := copy_from_root(source_node.get_parent(), destination_scene_root)
	var existed_copy := parent.find_child(source_node.name, false, false)
	if existed_copy:
		return existed_copy
	var dst := clone_node_shallow(source_node)
	dst.name = source_node.name
	parent.add_child(dst)
	dst.owner = destination_scene_root
	if dst is Node3D:
		(dst as Node3D).transform = (source_node as Node3D).transform
	elif dst is Node2D:
		(dst as Node2D).transform = (source_node as Node2D).transform
	return dst


static func clone_node_shallow(src: Node) -> Node:
	var dst := Node.new() if src.get_class() == "" else ClassDB.instantiate(src.get_class())

	copy_properties(src, dst)

	return dst


static func copy_properties(src: Node, dst = { }, type_filter: Array[Variant.Type] = []):
	# copy built-in properties only
	if not src.has_method("get"):
		return
	for p in src.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		if not type_filter.is_empty() and not (p.type in type_filter):
			continue
		var name = p.name
		if name == "script":
			continue
		var value = src.get(name)
		if value == ClassDB.class_get_property_default_value(src.get_class(), name):
			continue
		if value is Resource:
			value = value.duplicate_deep()
			value.resource_local_to_scene = true
			value.resource_path = ""
		if dst is Dictionary or dst.has_method("set"):
			dst.set(name, value)
	return dst


static func disable_culling(node: VisualInstance3D):
	RenderingServer.instance_set_ignore_culling(node.get_instance(), true)


static func is_actually_on_screen_3d(node: Node3D) -> bool:
	if not node.is_visible_in_tree():
		return false
	var cam := node.get_viewport().get_camera_3d()
	if cam == null:
		return false

	var aabb := _get_node_aabb(node)
	if aabb.size == Vector3.ZERO:
		return false

	var world_aabb := node.global_transform * aabb
	return is_aabb_in_frustum(cam, world_aabb)


static func is_aabb_in_frustum(cam: Camera3D, aabb: AABB) -> bool:
	var p := aabb.position
	var s := aabb.size

	var c := [
		p,
		p + Vector3(s.x, 0.0, 0.0),
		p + Vector3(0.0, s.y, 0.0),
		p + Vector3(0.0, 0.0, s.z),
		p + Vector3(s.x, s.y, 0.0),
		p + Vector3(s.x, 0.0, s.z),
		p + Vector3(0.0, s.y, s.z),
		p + s,
	]

	for v in c:
		if cam.is_position_in_frustum(v):
			return true

	var frustum := cam.get_frustum()

	var edges := [
		[c[0], c[1]],
		[c[0], c[2]],
		[c[0], c[3]],
		[c[7], c[4]],
		[c[7], c[5]],
		[c[7], c[6]],
		[c[1], c[4]],
		[c[1], c[5]],
		[c[2], c[4]],
		[c[2], c[6]],
		[c[3], c[5]],
		[c[3], c[6]],
	]

	for e in edges:
		if Geometry3D.segment_intersects_convex(e[0], e[1], frustum):
			return true

	return false


static func gridmap_aabb(gridmap: GridMap) -> AABB:
	var cells := gridmap.get_used_cells()
	if cells.is_empty():
		return AABB()

	var cell_size := gridmap.cell_size
	var half := cell_size * 0.5

	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)

	for cell in cells:
		var p := gridmap.map_to_local(cell)
		min_v = min_v.min(p - half)
		max_v = max_v.max(p + half)

	return AABB(min_v, max_v - min_v)


static func _extract_path(node: Node) -> NodePath:
	if node.get_parent() == null:
		return NodePath(node.name)
	return NodePath(String(_extract_path(node.get_parent())) + "/" + node.name)


static func _get_node_aabb(node: Node3D) -> AABB:
	if node is GPUParticles3D:
		return node.visibility_aabb

	if node is CPUParticles3D:
		return node.visibility_aabb

	if node is VisualInstance3D:
		return node.get_aabb()

	if node is GridMap:
		return gridmap_aabb(node)

	return AABB()
