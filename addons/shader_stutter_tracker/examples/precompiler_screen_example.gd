extends Node

@export var next_scene: PackedScene
@onready var precompiler := $ShaderPrecompiler

func _ready() -> void:
	await precompiler.all_shaders_compiled
	get_tree().change_scene_to_packed(next_scene)
