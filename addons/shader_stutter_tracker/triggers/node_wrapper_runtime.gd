class_name SSTRuntimeNodeWrapper
extends SSTNodeWrapper

var _node: Node
func _init(node: Node):
	_node = node 
func node_class() -> String:
	return _node.get_class()
func node_property(name: StringName) -> Variant:
	if _node is GPUParticles3D or _node is GPUParticles2D:
		if name.begins_with("draw_pass_"):
			var number := name.trim_prefix("draw_pass_").to_int() - 1
			if _node.draw_passes <= number:
				return null
	return _node.get(name)
func node_function(name: StringName, args: Array) -> Variant:
	return (_node[name] as Callable).callv(args)
func node_path() -> String:
	return SSTNodeUtils.get_node_path(_node)
