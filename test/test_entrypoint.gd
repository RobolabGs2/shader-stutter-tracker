extends GutTest

const DIFFERENT_NODE_TYPES_TEST = preload("uid://ei8c6p3rnk87")
const PRECOMPILER_TEST = preload("uid://bqgk1cai2mdap")

var scene: Node
var test_nodes: Array[SSTTBaseTest]


func before_all():
	scene = DIFFERENT_NODE_TYPES_TEST.instantiate()
	for child in scene.find_children("*"):
		if child is SSTTBaseTest:
			test_nodes.push_back(child)


func after_all():
	scene.free()


func test_scene_extractor_precompiler_config(t = use_parameters(test_nodes)):
	await t.run(self)


func test_precompiler():
	await autofree(PRECOMPILER_TEST.instantiate()).run(self)
