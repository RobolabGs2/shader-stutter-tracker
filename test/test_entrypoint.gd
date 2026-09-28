extends GutTest

const DIFFERENT_NODE_TYPES_TEST = preload("uid://ei8c6p3rnk87")
const PRECOMPILER_TEST = preload("uid://bqgk1cai2mdap")

var scenes: Array[Node]
var test_nodes: Array[SSTTBaseTest]


func before_all():
	var dir := DirAccess.open("res://test")
	for file in dir.get_files():
		var filepath := "res://test/" + file
		if file.ends_with("_tests.tscn"):
			var scene := (load(filepath) as PackedScene).instantiate()
			scenes.push_back(scene)
			for child in scene.find_children("*"):
				if child is SSTTBaseTest:
					test_nodes.push_back(child)
		elif file.ends_with("_test.tscn"):
			var scene := (load(filepath) as PackedScene).instantiate()
			scenes.push_back(scene)
			test_nodes.push_back(scene)


func after_all():
	for scene in scenes:
		scene.free()


func test_scenes(t = use_parameters(test_nodes)):
	await t.run(self)
