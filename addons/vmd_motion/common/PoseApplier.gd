class_name PoseApplier

## Pure skeleton pose manipulation utility
## No dependencies on VMD data or animation timing

static func apply_bone_pose(skeleton: Skeleton3D, bone_idx: int, position: Vector3, rotation: Quaternion, scale: Vector3 = Vector3.ONE):
	if bone_idx < 0 or bone_idx >= skeleton.get_bone_count():
		push_error("Invalid bone index: ", bone_idx)
		return

	skeleton.set_bone_pose_position(bone_idx, position)
	skeleton.set_bone_pose_rotation(bone_idx, rotation)
	if scale != Vector3.ONE:
		skeleton.set_bone_pose_scale(bone_idx, scale)

static func apply_face_pose(mesh: MeshInstance3D, blend_shape_name: String, weight: float):
	if not mesh or not mesh.mesh:
		return

	# Find blend shape index by name
	var mesh_instance = mesh as MeshInstance3D
	for i in range(mesh.mesh.get_blend_shape_count()):
		if mesh.mesh.get_blend_shape_name(i) == blend_shape_name:
			mesh.set("blend_shapes/" + blend_shape_name, weight)
			break

static func get_bone_pose(skeleton: Skeleton3D, bone_idx: int) -> Dictionary:
	if bone_idx < 0 or bone_idx >= skeleton.get_bone_count():
		return {}

	return {
		"position": skeleton.get_bone_pose_position(bone_idx),
		"rotation": skeleton.get_bone_pose_rotation(bone_idx),
		"scale": skeleton.get_bone_pose_scale(bone_idx)
	}

static func reset_bone_pose(skeleton: Skeleton3D, bone_idx: int):
	if bone_idx < 0 or bone_idx >= skeleton.get_bone_count():
		return

	skeleton.set_bone_pose_position(bone_idx, Vector3.ZERO)
	skeleton.set_bone_pose_rotation(bone_idx, Quaternion.IDENTITY)
	skeleton.set_bone_pose_scale(bone_idx, Vector3.ONE)

static func reset_all_bone_poses(skeleton: Skeleton3D):
	for i in range(skeleton.get_bone_count()):
		reset_bone_pose(skeleton, i)

# Test helper - create a simple test skeleton
static func create_test_skeleton() -> Skeleton3D:
	var skeleton = Skeleton3D.new()

	# Add root bone
	skeleton.add_bone("Root")
	skeleton.set_bone_rest(0, Transform3D.IDENTITY)

	# Add head bone
	skeleton.add_bone("Head")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)))

	return skeleton

# Test helper - validate bone pose was applied correctly
static func validate_bone_pose(skeleton: Skeleton3D, bone_idx: int, expected_pos: Vector3, expected_rot: Quaternion, tolerance: float = 0.001) -> bool:
	var actual_pos = skeleton.get_bone_pose_position(bone_idx)
	var actual_rot = skeleton.get_bone_pose_rotation(bone_idx)

	var pos_diff = (actual_pos - expected_pos).length()
	var rot_diff = actual_rot.angle_to(expected_rot)

	return pos_diff < tolerance and rot_diff < tolerance
