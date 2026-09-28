@abstract
class_name SSTNodeWrapper
extends RefCounted


@abstract func node_class() -> String


@abstract func node_path() -> String


@abstract func node_property(name: StringName) -> Variant


@abstract func node_function(name: StringName, args: Array) -> Variant


@abstract func node_copy_properties(dst = { }, type_filter: Array[Variant.Type] = []) -> Variant
