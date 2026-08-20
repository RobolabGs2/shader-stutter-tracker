class_name SSTTriggerCollector
extends RefCounted

var saw_triggers: Dictionary[Dictionary, int] = { }
var on_screen_triggers: Array[Node] = []
var saw_keys: Dictionary[String, Dictionary] = { }
var save_link_to_trigger := false


static func _get_or_load_or_null(default, path: String):
	if default is not EncodedObjectAsID:
		return default
	if path != "":
		return load(path)
	return null


static func grouped_report(nodes_report: Array) -> Dictionary:
	var materials: Array[Material] = []
	var environments: Array[Environment] = []
	var nodes: Array[Dictionary] = []
	for node in nodes_report:
		for trigger in node["triggers"]:
			if trigger["type"] == SSTTriggerCandidate.Type.RESOURCE:
				var path = trigger["path"]
				var t = trigger["trigger"]

				var resource: Resource = _get_or_load_or_null(t, path)
				if resource is Material:
					materials.push_back(resource)
				if resource is Shader:
					var shader := resource as Shader
					var resources: Array = trigger["resources"]
					if resources.size() > 1:
						var mat_desc = resources[resources.size() - 2]
						var p = mat_desc.path
						var r = mat_desc.resource
						@warning_ignore("confusable_local_declaration")
						var mat = _get_or_load_or_null(r, p)
						if mat != null:
							materials.push_back(mat)
							continue
					var mat := ShaderMaterial.new()
					mat.shader = shader
					materials.push_back(mat)
				if resource is Environment:
					environments.push_back(resource)
			else:
				nodes.push_back(node["tree_nodes"].back())
	return {
		"materials": materials,
		"environments": environments,
		"nodes": nodes,
	}


@warning_ignore("shadowed_variable")
func _init(save_link_to_trigger = false):
	self.save_link_to_trigger = save_link_to_trigger


func report() -> Array:
	return on_screen_triggers.map(
		func(n: Node):
			return n.get_meta(&"SSTReport"),
	)


func clear() -> void:
	on_screen_triggers.clear()


func size() -> int:
	return saw_keys.size()


func copy_as_scene() -> PackedScene:
	var packed_scene = PackedScene.new()
	var root = Node.new()
	root.name = "root"
	for item in on_screen_triggers:
		var node := SSTNodeUtils.copy_from_root(item, root)
		node.set_meta(&"SSTReport", item.get_meta(&"SSTReport"))
	assert(packed_scene.pack(root) == Error.OK)
	root.free()
	return packed_scene


func add_new_triggers(node: Node, triggers: Array[SSTTriggerCandidate]):
	var filtered := triggers.filter(
		func(t):
			return !saw_triggers.has(t.key),
	)
	if filtered.is_empty():
		return
	if not add_new_triggers_force(node, filtered):
		return
	var time = Time.get_ticks_msec()
	for t in filtered:
		saw_triggers[t.key] = time


func add_new_triggers_force(node: Node, triggers: Array[SSTTriggerCandidate]):
	if node in on_screen_triggers:
		return false
	node.set_meta(
		&"SSTReport",
		{
			"tree_nodes": SSTNodeUtils.owners_chain(node),
			"triggers": triggers.map(
				func(t: SSTTriggerCandidate):
					return t.to_dict(save_link_to_trigger),
			),
		},
	)
	on_screen_triggers.push_back(node)
	return true


func add_in_frustum_3d(node: Node, cam: Camera3D):
	if node is WorldEnvironment:
		add_new_triggers(node, SSTTriggerCandidate.from(node))
	elif node is Camera3D and cam == node and cam.environment != null:
		add_new_triggers(node, SSTTriggerCandidate.from(node))
	elif node is Node3D:
		if SSTNodeUtils.is_actually_on_screen_3d(node):
			add_new_triggers(node, SSTTriggerCandidate.from(node))
	elif node is CanvasItem:
		# if node is Control: TODO: is_actually_on_screen_2d
		add_new_triggers(node, SSTTriggerCandidate.from(node))
	for child in node.get_children():
		add_in_frustum_3d(child, cam)
