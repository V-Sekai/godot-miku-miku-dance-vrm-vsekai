extends Node3D

const FPS := 30.0

@export_file("*.vmd")
var starting_file_path: String
@export_node_path
var animator_path: NodePath
@onready
var camera: Camera3D
@onready
var animator: VRMAnimator = get_node(animator_path)
@export
var anim_scale := 0.07
@export
var mirror = false
@export
var locomotion_scale = Vector3.ONE
@export
var manual_update_time = false
@export
var enable_ik = true
@export
var enable_ikq = false
@export
var enable_shape = true

# Auto-bake settings
@export var auto_bake := false  # Automatically bake VMD to Godot Animation
@export var auto_bake_fps := 30.0  # FPS for auto-baking
@export var auto_bake_loop := true  # Loop mode for auto-baked animation

var start_time: int
var time = 0.0
var motion: Motion
var vmd_modifier
var max_frame: int
var current_frame: float = 0.0

func vmd_from_file(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	var vmd = VMD.new()
	vmd.read(f)
	return vmd

func load_motions(motion_paths: Array):
	var vmds = []
	for motion_path in motion_paths:
		var vmd = vmd_from_file(motion_path)
		if vmd:
			vmds.append(vmd)
		else:
			print("Failed to load VMD from ", motion_path)

	motion = Motion.new(vmds)

	print("DEBUG: Motion bones before translation:")
	for i in range(min(5, motion.bones.size())):  # Show first 5
		var key = motion.bones.keys()[i]
		print("  Motion bone: '%s'" % key)

	for i in range(motion.bones.size()):
		var key = motion.bones.keys()[i]
		var value = motion.bones.values()[i]
		var bone_name = StandardBones.fix_bone_name(key)
		if bone_name != key:
			print("Bone rename %s => %s" % [key, bone_name])
			motion.bones.erase(key)
			motion.bones[bone_name] = value

	max_frame = motion.get_max_frame()
	print_debug("Duration: %.2f s (%d frames)" % [max_frame / FPS, max_frame])

	if not vmd_modifier:
		var modifier_script = load("res://addons/vmd_motion/runtime/VMDSkeletonModifier3D.gd")
		vmd_modifier = modifier_script.new()
		if animator and animator.skeleton:
			animator.skeleton.add_child(vmd_modifier)
			vmd_modifier.owner = animator.owner

	vmd_modifier.set_motion(motion)
	vmd_modifier.anim_scale = anim_scale
	vmd_modifier.mirror = mirror
	vmd_modifier.locomotion_scale = locomotion_scale
	vmd_modifier.enable_ik = enable_ik
	vmd_modifier.enable_ikq = enable_ikq
	vmd_modifier.enable_shape = enable_shape

	if camera:
		camera.queue_free()
	if motion.camera.keyframes.size() > 0:
		camera = Camera3D.new()
		animator.add_child(camera)
		camera.owner = animator.owner

func _ready():
	print("VMDPlayer: _ready called, animator_path: ", animator_path)
	animator = get_node(animator_path)
	print("VMDPlayer: get_node result: ", animator)
	if animator:
		print("VMDPlayer: animator class: ", animator.get_class())
		print("VMDPlayer: animator script: ", animator.get_script())
		print("VMDPlayer: animator has skeleton: ", animator.has_method("get_human_scale"))
	else:
		print("VMDPlayer: animator is null!")
	set_process(false)
	# Disable auto-loading of starting file to prevent auto-play
	# if not starting_file_path.is_empty():
	#     load_motions([starting_file_path])

func _process(delta):
	if not manual_update_time:
		time = (Time.get_ticks_msec() - start_time) / 1000.0
	current_frame = time * FPS
	# Only update modifier if actively playing (process enabled)
	if vmd_modifier and is_processing():
		vmd_modifier.set_frame(current_frame)
		# Connect to modification_processed to handle post-modification tasks
		if not vmd_modifier.is_connected("modification_processed", _on_vmd_modification_processed):
			vmd_modifier.connect("modification_processed", _on_vmd_modification_processed)

func _on_vmd_modification_processed():
	# Handle camera animation after VMD modifications are complete
	if camera and motion:
		apply_camera_frame(current_frame)

func apply_camera_frame(frame: float):
	frame = max(frame, 0.0)
	var camera_sample = motion.camera.sample(frame) as Motion.CameraCurve.CameraSampleResult
	var target_pos = camera_sample.position
	var quat = Quaternion.IDENTITY
	var rot = camera_sample.rotation
	quat.set_euler(rot)
	var camera_pos = target_pos
	target_pos.z *= -1
	camera.global_transform.basis = Basis(quat)
	camera.global_transform.origin = (target_pos + (quat * Vector3.FORWARD) * camera_sample.distance) * anim_scale

	camera.fov = camera_sample.angle

## Animation Baking Functions

func get_animation_length() -> float:
	"""Return the total animation length in seconds"""
	if not motion:
		return 0.0
	return motion.get_max_frame() / FPS

func bake_vmd_animation(start_time: float, end_time: float, fps: float, loop: bool) -> Animation:
	"""Bake VMD animation to Godot Animation resource with IK and constraints

	Args:
		start_time: Start time in seconds
		end_time: End time in seconds
		fps: Frames per second for keyframe sampling
		loop: Enable infinite loop

	Returns:
		Godot Animation resource
	"""
	if not motion or not vmd_modifier:
		return null

	var animation = Animation.new()
	var duration = end_time - start_time
	animation.length = duration

	if loop:
		animation.loop_mode = Animation.LOOP_LINEAR
	else:
		animation.loop_mode = Animation.LOOP_NONE

	# STATIC WORK: Setup phase (done once)
	var bake_context = _prepare_bake_context(animation)

	# PER-FRAME WORK: Processing phase (done for each frame)
	_process_bake_frames(animation, bake_context, start_time, duration, fps)

	return animation

func _prepare_bake_context(animation: Animation) -> Dictionary:
	"""Static setup work done once before frame processing

	Returns:
		Dictionary containing pre-computed mappings and data
	"""
	# Include all motion bones (already translated) and filter to humanoid names
	print("=== VMD Bone Conversion Report ===")
	print("Total bones in motion: ", motion.bones.size())

	var bones_to_animate = []
	var bone_translations = {}  # bone_name -> translated_name

	for bone_name in motion.bones.keys():
		var translated_name = _translate_vrm_bone_name(bone_name)

		if translated_name.is_empty():
			# Skip bones that can't be translated to humanoid names
			print("SKIPPED (can't translate): ", bone_name, " -> ", translated_name)
			continue
		else:
			# Include bones that can be translated to humanoid names
			print("CONVERTED: ", bone_name, " -> ", translated_name)
			bones_to_animate.append(bone_name)
			bone_translations[bone_name] = translated_name

	print("Bones to animate: ", bones_to_animate.size())
	print("=== End Bone Conversion Report ===")

	# Create animation tracks for each bone using GeneralSkeleton scene path
	var bone_to_tracks = {}  # bone_name -> {pos_track_idx, rot_track_idx}

	for bone_name in bones_to_animate:
		# Use stored translated name from bone selection phase
		var translated_bone_name = bone_translations[bone_name]

		# Skip bones with empty translations (shouldn't happen, but safety check)
		if translated_bone_name.is_empty():
			print("WARNING: Skipping bone with empty translation: ", bone_name)
			continue

		# Position track - bone name becomes part of the property path
		var pos_track_idx = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(pos_track_idx, "GeneralSkeleton:" + translated_bone_name)

		# Rotation track - bone name becomes part of the property path
		var rot_track_idx = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(rot_track_idx, "GeneralSkeleton:" + translated_bone_name)

		bone_to_tracks[bone_name] = {"pos": pos_track_idx, "rot": rot_track_idx}

	# Store curve objects directly by bone name (no fragile indices)
	var bone_to_curve = {}  # bone_name -> Motion.BoneCurve
	for motion_bone_name in motion.bones.keys():
		if bones_to_animate.has(motion_bone_name):
			bone_to_curve[motion_bone_name] = motion.bones[motion_bone_name]

	return {
		"bones_to_animate": bones_to_animate,
		"bone_to_tracks": bone_to_tracks,
		"bone_to_curve": bone_to_curve
	}

func _process_bake_frames(animation: Animation, context: Dictionary, start_time: float, duration: float, fps: float) -> void:
	"""Per-frame processing work done for each animation frame"""
	var bones_to_animate = context.bones_to_animate
	var bone_to_tracks = context.bone_to_tracks
	var bone_to_curve = context.bone_to_curve

	var frame_count = int(duration * fps) + 1

	for frame_idx in range(frame_count):
		var frame_time = start_time + (frame_idx / fps)
		var vmd_frame = frame_time * FPS

		# Sample all bones for this frame
		for bone in bones_to_animate:
			if not bone_to_curve.has(bone):
				continue

			var curve = bone_to_curve[bone] as Motion.BoneCurve
			var tracks = bone_to_tracks[bone]

			# Sample VMD curve directly for original data
			var pos = Vector3.ZERO
			var rot_quat = Quaternion.IDENTITY

			if curve.keyframes.size() > 0:
				var sample_result := curve.sample(vmd_frame) as Motion.BoneCurve.BoneSampleResult
				if sample_result:
					pos = sample_result.position
					rot_quat = sample_result.rotation

			# Apply coordinate transformations with appropriate scaling for Godot
			pos *= 0.01  # Scale down for proper Miku units to meters conversion
			pos.z *= -1
			var temp = pos.x
			pos.x = pos.z
			pos.z = temp

			# Bone orientations are handled by StandardBones translation

			# Insert keyframes using cached track indices
			if tracks.pos != -1:
				animation.position_track_insert_key(tracks.pos, frame_time - start_time, pos)
			if tracks.rot != -1:
				animation.rotation_track_insert_key(tracks.rot, frame_time - start_time, rot_quat)

		# Minimal debug output - only print progress every 500 frames
		if int(frame_idx) % 500 == 0 and frame_idx > 0:
			print("Baking progress: %.1f%% (%d/%d frames)" % [
				(frame_idx / float(frame_count)) * 100.0,
				frame_idx,
				frame_count
			])

func _auto_bake_animation(vmd_path: String):
	"""Automatically bake the loaded VMD animation to a Godot Animation resource"""
	print("Auto-baking VMD animation...")

	var length = get_animation_length()
	var animation = bake_vmd_animation(0.0, length, auto_bake_fps, auto_bake_loop)

	if animation:
		# Generate save path based on VMD file location
		var save_path = _get_auto_bake_path(vmd_path)
		var save_result = ResourceSaver.save(animation, save_path)

		if save_result == OK:
			print("Auto-baked animation saved: ", save_path)
			print("Animation length: %.2f s, Tracks: %d, Loop: %s" % [
				animation.length, animation.get_track_count(),
				"Yes" if animation.loop_mode == Animation.LOOP_LINEAR else "No"
			])
		else:
			print("Failed to save auto-baked animation: ", save_result)
	else:
		print("Failed to auto-bake animation")

func _get_auto_bake_path(vmd_path: String) -> String:
	"""Generate the default save path for auto-baked animations"""
	var base_path = vmd_path.get_basename()  # Remove .vmd extension
	return base_path + ".tres"

func _translate_vrm_bone_name(japanese_name: String) -> String:
	"""Translate Japanese bone names to Godot humanoid

	Args:
		japanese_name: The Japanese bone name from VMD

	Returns:
		Godot humanoid bone name, or empty string if not mapped
	"""
	# First apply StandardBones character fixes
	var fixed_name = StandardBones.fix_bone_name(japanese_name)

	# Simple mapping from common VMD Japanese names to Godot humanoid names
	var vmd_to_humanoid = {
		"センター": "Hips",
		"下半身": "Hips",
		"上半身": "Spine",
		"上半身2": "Chest",
		"首": "Neck",
		"頭": "Head",
		"左目": "LeftEye",
		"右目": "RightEye",
		"左肩": "LeftShoulder",
		"左腕": "LeftUpperArm",
		"左ひじ": "LeftLowerArm",
		"左手首": "LeftHand",
		"右肩": "RightShoulder",
		"右腕": "RightUpperArm",
		"右ひじ": "RightLowerArm",
		"右手首": "RightHand",
		"左足": "LeftUpperLeg",
		"左ひざ": "LeftLowerLeg",
		"左足首": "LeftFoot",
		"左つま先": "LeftToes",
		"右足": "RightUpperLeg",
		"右ひざ": "RightLowerLeg",
		"右足首": "RightFoot",
		"右つま先": "RightToes",
		# Finger bones
		"左親指０": "LeftThumbMetacarpal",
		"左親指１": "LeftThumbProximal",
		"左親指２": "LeftThumbDistal",
		"左人指１": "LeftIndexProximal",
		"左人指２": "LeftIndexIntermediate",
		"左人指３": "LeftIndexDistal",
		"左中指１": "LeftMiddleProximal",
		"左中指２": "LeftMiddleIntermediate",
		"左中指３": "LeftMiddleDistal",
		"左薬指１": "LeftRingProximal",
		"左薬指２": "LeftRingIntermediate",
		"左薬指３": "LeftRingDistal",
		"左小指１": "LeftLittleProximal",
		"左小指２": "LeftLittleIntermediate",
		"左小指３": "LeftLittleDistal",
		"右親指０": "RightThumbMetacarpal",
		"右親指１": "RightThumbProximal",
		"右親指２": "RightThumbDistal",
		"右人指１": "RightIndexProximal",
		"右人指２": "RightIndexIntermediate",
		"右人指３": "RightIndexDistal",
		"右中指１": "RightMiddleProximal",
		"右中指２": "RightMiddleIntermediate",
		"右中指３": "RightMiddleDistal",
		"右薬指１": "RightRingProximal",
		"右薬指２": "RightRingIntermediate",
		"右薬指３": "RightRingDistal",
		"右小指１": "RightLittleProximal",
		"右小指２": "RightLittleIntermediate",
		"右小指３": "RightLittleDistal"
	}

	if vmd_to_humanoid.has(fixed_name):
		return vmd_to_humanoid[fixed_name]

	return ""  # Not found in mapping



func _get_incremental_save_path(base_path: String) -> String:
	"""Generate an incremental filename if the base path already exists

	Args:
		base_path: The desired save path (should end with .tres)

	Returns:
		A unique path that doesn't conflict with existing files
	"""
	var file_path = base_path
	var counter = 1
	var original_base = base_path.get_basename()  # Get base name once from original path
	var extension = base_path.get_extension()

	# Check if the base file exists
	while FileAccess.file_exists(file_path) or ResourceLoader.exists(file_path):
		# Insert counter before the file extension using original base
		file_path = original_base + "_%03d" % counter + "." + extension
		counter += 1

		# Prevent infinite loops (though unlikely)
		if counter > 999:
			break

	return file_path

func manual_bake_animation(vmd_path: String = "") -> Animation:
	"""Manually bake the current VMD animation to a Godot Animation resource

	Args:
		vmd_path: Optional path to save the animation (uses auto-generated path if empty)

	Returns:
		The baked Animation resource, or null if baking failed
	"""
	if not motion:
		print("No VMD motion loaded to bake")
		return null

	print("Manually baking VMD animation...")

	var length = get_animation_length()
	var animation = bake_vmd_animation(0.0, length, auto_bake_fps, auto_bake_loop)

	if animation:
		# Generate save path - ensure it's in the project directory
		var save_path = vmd_path
		if save_path.is_empty():
			save_path = _get_auto_bake_path("manual_bake")
		else:
			# Convert absolute path to project-relative path
			if save_path.begins_with(ProjectSettings.globalize_path("res://")):
				save_path = ProjectSettings.localize_path(save_path)
			else:
				# If it's an absolute path, try to make it relative to the project
				var project_dir = ProjectSettings.globalize_path("res://")
				if save_path.begins_with(project_dir):
					save_path = "res://" + save_path.substr(project_dir.length())
				else:
					# Fallback: save to user directory
					save_path = "user://" + save_path.get_file().get_basename() + ".tres"

		# Ensure the path ends with .tres
		if not save_path.ends_with(".tres"):
			save_path = save_path.get_basename() + ".tres"

		# Generate incremental filename if file already exists
		save_path = _get_incremental_save_path(save_path)

		print("Attempting to save animation to: ", save_path)
		var save_result = ResourceSaver.save(animation, save_path)

		if save_result == OK:
			print("Manually baked animation saved: ", save_path)
			print("Animation length: %.2f s, Tracks: %d, Loop: %s" % [
				animation.length, animation.get_track_count(),
				"Yes" if animation.loop_mode == Animation.LOOP_LINEAR else "No"
			])
			return animation
		else:
			print("Failed to save manually baked animation: ", save_result)
			print("Save path was: ", save_path)
			# Try fallback to user directory
			var fallback_path = "user://" + save_path.get_file().get_basename()
			print("Trying fallback save to: ", fallback_path)
			save_result = ResourceSaver.save(animation, fallback_path)
			if save_result == OK:
				print("Fallback save successful: ", fallback_path)
				return animation
			else:
				print("Fallback save also failed: ", save_result)
	else:
		print("Failed to manually bake animation")

	return null
