@abstract class_name SSTShaderPrecompilerConfigBase
extends Resource


@abstract func get_materials() -> Array[Material]


@abstract func get_environments() -> Array[Environment]


## Array of node description in format:
##	{
##		&"class": "class name",
##		&"properties": { &"property_name": property_value}
##	}
@abstract func get_nodes() -> Array[Dictionary]
