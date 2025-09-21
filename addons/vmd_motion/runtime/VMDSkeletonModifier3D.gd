@tool
extends SkeletonModifier3D

const FPS := 30.0

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
var anim_scale := 0.07
var mirror = false
var locomotion_scale = Vector3.ONE
var enable_ik = true
var enable_ikq = false
var enable_shape = true
var smoothing_factor = 0.3  # Adjust this value to control smoothing (0.0 = no smoothing, 1.0 = instant)

var last_ik_enable = {}
var previous_positions = {}
var previous_rotations = {}
var previous_chest_global: Transform3D

func _ready():
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
			# Debug: Check head bone keyframes
			if bone_name == "頭":
				print("DEBUG: Head bone found in VMD with ", motion.bones[bone_name].keyframes.size(), " keyframes")
		else:
			bone_curves.append(Motion.BoneCurve.new())
			# Debug: Check if head bone is missing
			if bone_name == "頭":
				print("DEBUG: Head bone NOT found in VMD")

	max_frame = motion.get_max_frame()

	# Log all bones with VMD animation data (summary)
	print("\n=== VMD Animation Data Summary ===")
	print("Total frames: ", max_frame)
	print("Bones with animation data:")
	for bone_name in motion.bones:
		var curve = motion.bones[bone_name] as Motion.BoneCurve
		var keyframe_count = curve.keyframes.size()
		if keyframe_count > 0:
			print("  - ", bone_name, " (", keyframe_count, " keyframes)")
	print("===================================\n")

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

	# Sort bones by hierarchy depth (leaf to root)
	bones_to_process.sort_custom(func(a, b): return get_bone_depth(a.target_bone_skel_i) > get_bone_depth(b.target_bone_skel_i))

	for bone in bones_to_process:
		# Find the corresponding curve index
		var curve_index = -1
		for j in range(vmd_skeleton.bones.size()):
			if vmd_skeleton.bones[vmd_skeleton.bones.keys()[j]] == bone:
				curve_index = j
				break

		if curve_index == -1:
			continue

		var curve = bone_curves[curve_index] as Motion.BoneCurve

		var pos := Vector3.ZERO
		var rot := Quaternion.IDENTITY

		if curve.keyframes.size() > 0:
			var sample_result := curve.sample(frame) as Motion.BoneCurve.BoneSampleResult
			if sample_result:
				pos = sample_result.position
				rot = sample_result.rotation

		if mirror:
			pos.x *= -1
			rot.y *= -1
			rot.z *= -1

		# Apply animation scale to position (convert from MMD units to Godot units)
		pos *= anim_scale

		# Minimal debug logging - only show head bone every 200 frames
		if bone.name == StandardBones.get_bone_i("頭") and int(current_frame) % 200 == 0:
			print("Frame ", current_frame, ": Head active")

		# Apply smoothing to prevent jumps when skipping frames
		if not previous_positions.has(bone.name):
			previous_positions[bone.name] = pos
			previous_rotations[bone.name] = rot
		else:
			pos = previous_positions[bone.name].lerp(pos, smoothing_factor)
			rot = previous_rotations[bone.name].slerp(rot, smoothing_factor)
			previous_positions[bone.name] = pos
			previous_rotations[bone.name] = rot

		# Update the Node3D transform for IK calculations and VMDSkeleton processing
		bone.node.transform.origin = pos + bone.local_position_0
		bone.node.transform.basis = Basis(rot)

		# Apply locomotion scale for specific bones
		if bone.name == StandardBones.get_bone_i("全ての親") or bone.name == StandardBones.get_bone_i("センター") \
				or bone.name == StandardBones.get_bone_i("左足ＩＫ") or bone.name == StandardBones.get_bone_i("右足ＩＫ"):
			if locomotion_scale != Vector3.ONE:
				bone.node.transform = bone.node.transform.scaled(locomotion_scale)

		# Debug: Track chest bone global transform differences
		if bone.name == StandardBones.get_bone_i("上半身2"):  # Chest bone
			var current_global = bone.node.global_transform
			if previous_chest_global != Transform3D.IDENTITY:
				var pos_diff = (current_global.origin - previous_chest_global.origin).length()
				var rot_diff = current_global.basis.get_rotation_quaternion().angle_to(previous_chest_global.basis.get_rotation_quaternion())
				if int(current_frame) % 50 == 0:  # Log every 50 frames
					print("Chest Δ - Frame: ", current_frame, " PosΔ: ", "%.4f" % pos_diff, " RotΔ: ", "%.4f" % rot_diff, "°")
			previous_chest_global = current_global
