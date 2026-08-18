@tool
extends EditorExportPlugin


func _begin_customize_resources(platform: EditorExportPlatform, features: PackedStringArray):
	return true

func _get_customization_configuration_hash() -> int:
	return 1 # Customization the same for all configurations

func _customize_resource(resource: Resource, path: String) -> Resource:
	if resource is SSTScenesCompilerConfig:
		resource._on_export()
	return resource
