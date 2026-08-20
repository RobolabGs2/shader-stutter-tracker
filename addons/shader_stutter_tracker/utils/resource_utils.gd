class_name SSTResourceUtils
extends Object

static func is_shader_with_mode(mat: Material, mode: Shader.Mode):
	return mat is ShaderMaterial and (mat as ShaderMaterial).shader.get_mode() == mode


static func make_skinned_quad() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var verts := [
		Vector3(-0.5, -0.5, 0.0),
		Vector3(0.5, -0.5, 0.0),
		Vector3(0.5, 0.5, 0.0),
		Vector3(-0.5, 0.5, 0.0),
	]

	for v in verts:
		st.set_bones(PackedInt32Array([0, 0, 0, 0]))
		st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		st.add_vertex(v)

	st.add_index(0)
	st.add_index(1)
	st.add_index(2)
	st.add_index(0)
	st.add_index(2)
	st.add_index(3)

	return st.commit()


static func is_scene_path(path: String) -> bool:
	var scene_extensions := ResourceLoader.get_recognized_extensions_for_type("PackedScene")
	return path.get_extension().to_lower() in scene_extensions


static func walk_dependencies_graph(process: Callable, path: String, depth = 0, processed = { }):
	if processed.has(path):
		return
	processed.set(path, true)
	process.call(path, depth)
	for dependency in ResourceLoader.get_dependencies(path):
		var dep_path := parse_dependency_path(dependency)
		walk_dependencies_graph(process, dep_path, depth + 1, processed)


static func parse_dependency_path(dependency: String) -> String:
	if dependency.contains("::"):
		return dependency.get_slice("::", 2)
	return dependency
