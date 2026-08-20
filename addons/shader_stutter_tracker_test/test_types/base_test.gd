@abstract class_name SSTTBaseTest
extends Node


func _to_string() -> String:
	return name


## Awaitable
@abstract func run(t: GutTest) -> void
