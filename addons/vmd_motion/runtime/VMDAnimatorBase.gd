extends Node3D

class_name VMDAnimatorBase

var skeleton: Skeleton3D

func find_humanoid_bone(bone: String) -> int:
	return -1

func get_human_scale() -> float:
	return VMDUtils.get_bone_global_rest(skeleton, find_humanoid_bone("hips")).origin.y

func set_blend_shape_value(blend_shape_name: String, value: float):
	pass
