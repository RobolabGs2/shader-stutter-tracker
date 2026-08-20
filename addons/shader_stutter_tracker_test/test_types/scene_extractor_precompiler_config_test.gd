class_name SSTTScemeExtractorPrecompilerConfigTest
extends SSTTBaseTest

@export var expected := SSTShaderPrecompilerConfig.new()


@warning_ignore("shadowed_variable")
static func arrays_are_equal_without_order(expected: Array, actual: Array) -> Dictionary:
	var not_in_expected := []
	var not_in_actual := []
	for item in expected:
		if item not in actual:
			not_in_actual.push_back(item)
	for item in actual:
		if item not in expected:
			not_in_expected.push_back(item)
	return {
		"equal": not_in_expected.size() == 0 and not_in_actual.size() == 0,
		"not_in_expected": not_in_expected,
		"not_in_actual": not_in_actual,
	}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func run(t: GutTest) -> void:
	var actual := SSTSceneExtractorPrecompilerConfig.new()
	var packed_scene := PackedScene.new()
	packed_scene.pack(self)
	actual.scenes = [packed_scene]
	actual.refresh()
	var material_diff := arrays_are_equal_without_order(expected.materials, actual.materials)
	var env_diff := arrays_are_equal_without_order(expected.environments, actual.environments)
	var nodes_diff := arrays_are_equal_without_order(expected.nodes, actual.nodes)
	@warning_ignore("shadowed_variable")
	var success := true
	var report := ""
	for pairs in [
		["materials", material_diff],
		["environments", env_diff],
		["nodes", nodes_diff],
	]:
		var key: String = pairs[0]
		var diff: Dictionary = pairs[1]
		if diff["equal"]:
			report += "%s: OK\n" % key
		else:
			success = false
			report += "%s: FAILED, diff:\n" % key
			for value in diff["not_in_expected"]:
				report += "+ %s\n" % value
			for value in diff["not_in_actual"]:
				report += "- %s\n" % value
			report += "\n"
	if success:
		t.pass_test(report)
	else:
		t.fail_test(report)
