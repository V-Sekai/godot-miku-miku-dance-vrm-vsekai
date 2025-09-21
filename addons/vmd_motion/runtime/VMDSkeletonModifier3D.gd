@tool
extends SkeletonModifier3D

const FPS := 30.0

# Root motion bone indices (bones that should have position animation applied)
var ROOT_MOTION_BONES = [0, 1, 2]  # 全ての親, センター, グルーブ

# VMD animation data
var motion: Motion
var bone_curves = []
var morph: Morph
var vmd_skeleton: VMDSkeleton
var apply_ikq = false

# Animation state
var current_frame: float = 0.0
var max_frame: int = 0
var first_frame_number: int = 0

# Settings
@export var anim_scale := 0.01  # Convert MMD centimeters to Godot meters
var mirror = false
var locomotion_scale = Vector3.ONE
var enable_ik = true
var enable_ikq = false
var enable_shape = true
var smoothing_factor = 0.3  # Adjust this value to control smoothing (0.0 = no smoothing, 1.0 = instant)

var last_ik_enable = {}
var previous_positions = {}
var previous_rotations = {}

func _ready():
	print("VMDSkeletonModifier3D _ready called")
	# Initialization is handled in set_motion()
	pass

func _find_animator() -> VRMAnimator:
	# The modifier is a child of the skeleton, so traverse up to find the animator
	var current = get_parent()
	while current:
		if current is VRMAnimator:
			return current
		current = current.get_parent()
	return null

func set_motion(new_motion: Motion):
	motion = new_motion
	if not motion:
		return

	# Initialize bone curves
	bone_curves = []
	for i in StandardBones.bone_names.size():
		var bone_name = StandardBones.get_bone_name(i)
		if bone_name in motion.bones:
			bone_curves.append(motion.bones[bone_name])
		else:
			bone_curves.append(Motion.BoneCurve.new())

	max_frame = motion.get_max_frame()

	# Calculate first frame number (skip linear motion start frames)
	first_frame_number = 0
	for bone_i in [StandardBones.get_bone_i("全ての親"), StandardBones.get_bone_i("センター"), StandardBones.get_bone_i("グルーブ")]:
		var keyframes = bone_curves[bone_i].keyframes as Array
		if keyframes.size() >= 2 and (keyframes[0] as VMD.BoneKeyframe).frame_number == 0:
			var linear_motion_t = keyframes[0].position != keyframes[1].position \
				and keyframes[1].interp.X.is_linear() and keyframes[1].interp.Y.is_linear() \
				and keyframes[1].Z.is_linear()
			var linear_motion_q = keyframes[0].rotation != keyframes[1].rotation \
				and keyframes[1].interp.rotation.is_linear()
			if linear_motion_t or linear_motion_q:
				first_frame_number = max(first_frame_number, keyframes[1].frame_number)

	# Check for IK rotation keyframes
	var ik_qframes = {}
	for bone_i in [StandardBones.get_bone_i("左足ＩＫ"), StandardBones.get_bone_i("右足ＩＫ")]:
		var curve = bone_curves[bone_i] as Motion.BoneCurve
		var ik_count = 0
		for i in range(curve.keyframes.size()):
			var keyframe = curve.keyframes[i] as VMD.BoneKeyframe
			if keyframe.rotation != Quaternion.IDENTITY:
				ik_count += 1
		if ik_count > 1:
			ik_qframes[bone_i] = ik_count
	apply_ikq = ik_qframes.size() > 0

	# Initialize VMD skeleton for IK and constraints
	if not vmd_skeleton:
		# Find the animator by traversing up the tree
		var animator = _find_animator()
		if animator:
			vmd_skeleton = VMDSkeleton.new(animator, self)
			morph = Morph.new(animator, motion.faces.keys())

			# Enable IK for bones that have keyframes
			for bone_i in [StandardBones.get_bone_i("左足ＩＫ"), StandardBones.get_bone_i("左つま先ＩＫ"),
							StandardBones.get_bone_i("右足ＩＫ"), StandardBones.get_bone_i("右つま先ＩＫ")]:
				vmd_skeleton.bones[vmd_skeleton.bones.keys()[bone_i]].ik_enabled = bone_curves[bone_i].keyframes.size() > 1

func set_frame(frame: float):
	current_frame = max(frame, 0.0)

func get_bone_depth(bone_idx: int) -> int:
	var skeleton = get_skeleton()
	if not skeleton:
		return 0

	var depth = 0
	var current = bone_idx
	while current != -1:
		current = skeleton.get_bone_parent(current)
		depth += 1
	return depth

func _process_modification():
	if not motion or not vmd_skeleton:
		return

	var skeleton = get_skeleton()
	if not skeleton:
		return

	var frame = current_frame

	# Apply face shapes
	if enable_shape:
		apply_face_frame(frame)

	# Apply IK enabling/disabling
	apply_ik_frame(frame)

	# Apply bone poses
	apply_bone_frame(frame)

	# Apply IK and constraints
	vmd_skeleton.apply_constraints(enable_ik, enable_ik and enable_ikq)
	vmd_skeleton.apply_targets()

	# Apply morph targets
	morph.apply_targets()

func apply_face_frame(frame: float):
	for key in motion.faces:
		var value = motion.faces[key] as Motion.FaceCurve
		if key in morph.shapes:
			var shape = morph.shapes[key]
			shape.weight = value.sample(frame)

func apply_ik_frame(frame: float):
	var current_ik_enable := motion.ik.sample(frame)
	if current_ik_enable.hash() == last_ik_enable.hash():
		return
	last_ik_enable = current_ik_enable
	if current_ik_enable == null:
		return
	
	for i in range(current_ik_enable.size()):
		var name = current_ik_enable.keys()[i]
		var enable = current_ik_enable.values()[i]
		var bone_i = StandardBones.get_bone_i(name)
		if bone_i != -1:
			if mirror:
				bone_i = StandardBones.get_bone_i(StandardBones.MIRROR_BONE_NAMES[i])
			if vmd_skeleton.bones[vmd_skeleton.bones.keys()[bone_i]].ik_enabled != enable:
				print("%s, %s", name, str(enable))
			vmd_skeleton.bones[vmd_skeleton.bones.keys()[bone_i]].ik_enabled = enable

func apply_bone_frame(frame: float):
	var skeleton = get_skeleton()

	# Animate all bones that have VMD animation data, from leaf to root
	var bones_to_process = []
	for i in range(vmd_skeleton.bones.size()):
		var bone = vmd_skeleton.bones[vmd_skeleton.bones.keys()[i]] as VMDSkeleton.VMDSkelBone
		if bone.target_bone_skel_i != -1:
			bones_to_process.append(bone)

	# Sort bones by hierarchy depth (root to leaf)
	bones_to_process.sort_custom(func(a, b): return get_bone_depth(a.target_bone_skel_i) < get_bone_depth(b.target_bone_skel_i))

	for bone in bones_to_process:
		# Find the corresponding curve index
		var curve_index = -1
		for j in range(vmd_skeleton.bones.size()):
			if vmd_skeleton.bones[vmd_skeleton.bones.keys()[j]] == bone:
				curve_index = j
				break

		if curve_index == -1:
			print("Unmapped bone: ", bone.name, " (", StandardBones.get_bone_name(bone.name), ")")
			continue

		var curve = bone_curves[curve_index] as Motion.BoneCurve

		var pos := Vector3.ZERO
		var rot := Quaternion.IDENTITY

		if curve.keyframes.size() > 0:
			var sample_result := curve.sample(frame) as Motion.BoneCurve.BoneSampleResult
			if sample_result:
				pos = sample_result.position
				rot = sample_result.rotation

		# Only apply position animation to root motion bones
		if not (curve_index in ROOT_MOTION_BONES):
			pos = Vector3.ZERO

		if mirror:
			pos.x *= -1
			rot.y *= -1
			rot.z *= -1

		# Apply animation scale to position (convert from MMD units to Godot units)
		pos *= anim_scale

		# Apply smoothing to prevent jumps when skipping frames
		if not previous_positions.has(bone.name):
			previous_positions[bone.name] = pos
			previous_rotations[bone.name] = rot
		else:
			pos = previous_positions[bone.name].lerp(pos, smoothing_factor)
			rot = previous_rotations[bone.name].slerp(rot, smoothing_factor)
			previous_positions[bone.name] = pos
			previous_rotations[bone.name] = rot

		# Apply VMD data as local deltas from rest pose to prevent bone stretching
		# VMD position is in bone's local coordinate system, so transform by rest rotation
		var desired_local_pos = bone.rest_local_position + (bone.rest_local_rotation * pos)
		var desired_local_rot = bone.rest_local_rotation * rot

		# Apply locomotion scale for specific bones
		var final_local_pos = desired_local_pos
		var final_local_rot = desired_local_rot
		if bone.name == StandardBones.get_bone_i("全ての親") or bone.name == StandardBones.get_bone_i("センター") \
				or bone.name == StandardBones.get_bone_i("左足ＩＫ") or bone.name == StandardBones.get_bone_i("右足ＩＫ"):
			if locomotion_scale != Vector3.ONE:
				# Apply locomotion scaling to the local position (transform by rest rotation)
				final_local_pos = bone.rest_local_position + (bone.rest_local_rotation * (pos * locomotion_scale))

		# Update the Node3D local transform for IK calculations and VMDSkeleton processing
		bone.node.transform = Transform3D(Basis(final_local_rot), final_local_pos)
