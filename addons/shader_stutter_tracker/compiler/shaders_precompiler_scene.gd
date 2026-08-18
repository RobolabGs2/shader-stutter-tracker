extends Node

@export var next_scene: PackedScene
@onready var precompiler := $ShaderPrecompiler


func run_next_scene() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_packed(next_scene)
