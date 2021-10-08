extends VMDPlayer

class_name VMDPlayerBake

func vmd_from_file(path: String):
	var f = File.new()
	f.open(path, File.READ)
	var vmd = VMD.new()
	vmd.read(f)
	return vmd

func load_motions(motion_paths: Array):
	var vmds = []
	for motion_path in motion_paths:
		vmds.append(vmd_from_file(motion_path))
	motion = Motion.new(vmds)
	
	for i in range(motion.bones.size()):
		var key = motion.bones.keys()[i]
		var value = motion.bones.values()[i]
		var bone_name = StandardBones.fix_bone_name(key)
		if bone_name != key:
			print("Bone rename %s => %s" % [key, bone_name])
			motion.bones.erase(key)
			motion.bones[bone_name] = value
	bone_curves = []
	for i in StandardBones.bone_names.size():
		var bone_name = StandardBones.get_bone_name(i)
		if bone_name in motion.bones:
			bone_curves.append(motion.bones[bone_name])
		else:
			bone_curves.append(Motion.BoneCurve.new())
	
	max_frame = motion.get_max_frame()
	print_debug("Duration: %.2f s (%d frames)" % [max_frame / FPS, max_frame])
	var bone_frames_str = PoolStringArray()
	bone_frames_str.resize(motion.bones.size())
	for i in motion.bones.size():
		var curve = motion.bones.values()[i] as Motion.BoneCurve
		bone_frames_str.set(i, "%s (%d)" % [motion.bones.keys()[i], curve.keyframes.size()])
#	print_debug("Bone frames: ", bone_frames_str.join(", "))
	
	var face_frames_str = PoolStringArray()
	face_frames_str.resize(motion.faces.size())
	for i in motion.faces.size():
		var curve = motion.faces.values()[i] as Motion.FaceCurve
		face_frames_str.set(i, "%s (%d)" % [motion.faces.keys()[i], curve.keyframes.size()])
#	print_debug("Face frames: ", face_frames_str.join(", "))
	
	first_frame_number = 0
	for bone_i in [StandardBones.get_bone_i("全ての親"), StandardBones.get_bone_i("全ての親"), StandardBones.get_bone_i("全ての親")]:
		var keyframes = bone_curves[bone_i].keyframes as Array
		if keyframes.size() >= 2 and (keyframes[0] as VMD.BoneKeyframe).frame_number == 0:
			var linear_motion_t = keyframes[0].position != keyframes[1].position \
				and keyframes[1].interp.X.is_linear() and keyframes[1].interp.Y.is_linear() \
				and keyframes[1].Z.is_linear()
			var linear_motion_q = keyframes[0].rotation != keyframes[1].rotation \
				and keyframes[1].interp.rotation.is_linear()
			if linear_motion_t or linear_motion_q:
				first_frame_number = max(first_frame_number, keyframes[1].frame_number)
				print_debug("skipping frame: (%s, (%d))", keyframes[1].name, keyframes[1].frame_number)
	
	var ik_qframes = {}
	
	for bone_i in [StandardBones.get_bone_i("左足ＩＫ"), StandardBones.get_bone_i("右足ＩＫ")]:
		var curve = bone_curves[bone_i] as Motion.BoneCurve
		var ik_count = 0
		for i in range(curve.keyframes.size()):
			var keyframe = curve.keyframes[i] as VMD.BoneKeyframe
			if keyframe.rotation != Quat.IDENTITY:
				ik_count += 1
		if ik_count > 1:
			ik_qframes[bone_i] = ik_count
	apply_ikq = ik_qframes.size() > 0
	
	if not vmd_skeleton:
		print("scale suggestion: %.2f" % [0.07*animator.get_human_scale()])
		anim_scale = 0.07*animator.get_human_scale()
		# TODO: this
		#var source_overrides = {}
		vmd_skeleton = VMDSkeleton.new(animator, self)
		morph = Morph.new(animator, motion.faces.keys())
	for bone_i in [StandardBones.get_bone_i("左足ＩＫ"), StandardBones.get_bone_i("左つま先ＩＫ"), 
					StandardBones.get_bone_i("右足ＩＫ"), StandardBones.get_bone_i("右つま先ＩＫ")]:
		vmd_skeleton.bones[bone_i].ik_enabled = bone_curves[bone_i].keyframes.size() > 1
	scale_overrides.resize(vmd_skeleton.bones.size())
	
	for i in scale_overrides.size():
		scale_overrides.set(i, 0.0)
	
	for bone_i in [StandardBones.get_bone_i("左つま先ＩＫ"), StandardBones.get_bone_i("右つま先ＩＫ")]:
		var curve_local_pos_0 := -(bone_curves[bone_i] as Motion.BoneCurve).estimate_rotation_center_from_position()
		var bone_local_pos_0 := (vmd_skeleton.bones[bone_i] as VMDSkeleton.VMDSkelBone).local_position_0
		print(curve_local_pos_0)
		if curve_local_pos_0 != Vector3.ZERO:
			scale_overrides.set(bone_i, bone_local_pos_0.length() / curve_local_pos_0.length())
			print("override scale %s (%.4f)" % [StandardBones.get_bone_name(bone_i), scale_overrides[bone_i]])
	
	if motion:
		set_process(true)
		start_time = OS.get_ticks_msec()
		if camera:
			camera.queue_free()
		if motion.camera.keyframes.size() > 0:
			camera = Camera.new()
			animator.add_child(camera)
			camera.make_current()
		
func _ready():
	animator = get_node(animator_path)
	set_process(false)
	if not starting_file_path.empty():
		load_motions([starting_file_path])


func save_motion(basename):
	var animation_bone_rest = Animation.new()
	
	for bone_id in animator.skeleton.get_bone_count():
		var track_i = animation_bone_rest.get_track_count()
		var path = str(animator.skeleton.get_owner().get_path_to(animator.skeleton)) + ":" + animator.skeleton.get_bone_name(bone_id)
		var rest_bone = animator.rest_bones[path]
		animation_bone_rest.add_track(Animation.TYPE_TRANSFORM)
		animation_bone_rest.track_set_path(track_i, path)
		if rest_bone == null:
			animation_bone_rest.transform_track_insert_key(track_i, 0, Vector3(), Quat(), Vector3(1.0, 1.0, 1.0))
		var rot = rest_bone["rest_delta"]
		var loc = rest_bone["loc"]
		animation_bone_rest.transform_track_insert_key(track_i, 0, -loc, rot.get_rotation_quat().inverse(), 
			Vector3(1, 1, 1) + (rot.get_scale() - Vector3(1, 1, 1)))
	var new_anims : Dictionary
	new_anims["RESET"] = animation_bone_rest
	var animation = Animation.new()
	for bone_id in animator.skeleton.get_bone_count():
		var track_i = animation.get_track_count()
		animation.add_track(Animation.TYPE_TRANSFORM)
		var path = str(animator.skeleton.get_owner().get_path_to(animator.skeleton)) + ":" + animator.skeleton.get_bone_name(bone_id)
		animation.track_set_path(track_i, path)
		animation.transform_track_insert_key(track_i, 0.0, Vector3(), Quat(), Vector3(1.0, 1.0, 1.0))
	animation.length = max_frame / FPS
	for frame_i in range(first_frame_number, max_frame):
		update_frame(frame_i)
		
		for vmd_bone_id in vmd_skeleton.bones.size():
			var target = StandardBones.bones[vmd_bone_id].target
			var rest_new : Transform
			if target == null:
				continue
			var bone_id = animator.find_humanoid_bone(target)	
			var bone = vmd_skeleton.bones[vmd_bone_id]
			var vmd_xform : Transform = animator.skeleton.get_bone_global_pose(bone_id)
			
			var bone_size : int = animator.skeleton.get_bone_count()
			if bone_id >= bone_size:
				continue
			var parent : int = animator.skeleton.get_bone_parent(bone_id)
			var local_pose : Transform
			if parent >= 0:
				var conversion_transform : Transform = animator.skeleton.get_bone_global_pose(parent) * animator.skeleton.get_bone_rest(bone_id)
				local_pose = conversion_transform.affine_inverse() * vmd_xform;
			else:
				local_pose = vmd_xform
			
			var new_loc : Vector3 = local_pose.origin
			var new_rot : Quat = local_pose.basis.get_rotation_quat()
			var new_scale : Vector3 = local_pose.basis.get_scale()
			animation.transform_track_insert_key(bone_id, frame_i / FPS, new_loc, new_rot, new_scale)
	new_anims["MMD Animation " + basename] = animation
	return new_anims
	
func update_frame(frame: float):
	if enable_shape:
		apply_face_frame(frame)
	apply_ik_frame(frame)
	apply_bone_frame(frame)
	vmd_skeleton.apply_constraints(enable_ik, enable_ik and enable_ikq)
	vmd_skeleton.apply_targets()
	morph.apply_targets()
	if camera:
		apply_camera_frame(frame)

func apply_face_frame(frame: float):
	frame = max(frame, 0.0)

	for key in motion.faces:
		var value = motion.faces[key] as Motion.FaceCurve
		if key in morph.shapes:
			var shape = morph.shapes[key]
			shape.weight = value.sample(frame)

func apply_camera_frame(frame: float):
	frame = max(frame, 0.0)
	var camera_sample = motion.camera.sample(frame) as Motion.CameraCurve.CameraSampleResult
	var target_pos = camera_sample.position * 0.07
	var quat = Quat.IDENTITY
	var rot = camera_sample.rotation
	quat.set_euler(rot)
	var camera_pos = target_pos
	target_pos.z *= -1
	camera.global_transform.basis = Basis(quat)
	camera.global_transform.origin = target_pos + (quat * Vector3.FORWARD) * camera_sample.distance * 0.08

	camera.fov = camera_sample.angle

func apply_bone_frame(frame: float):
	frame = max(frame, 0.0)
	for i in range(vmd_skeleton.bones.size()):
		var bone = vmd_skeleton.bones[i] as VMDSkeleton.VMDSkelBone
		var curve = bone_curves[i] as Motion.BoneCurve
		var sample_result := curve.sample(frame) as Motion.BoneCurve.BoneSampleResult
		if not sample_result:
			continue
		var pos := sample_result.position
		var rot = sample_result.rotation
		
		if mirror:
			pos.x *= -1
			rot.y *= -1
			rot.z *= -1
		var scal = scale_overrides[bone.name]
		if scal == 0:
			scal = anim_scale
		pos *= scal
		
		if bone.name == StandardBones.get_bone_i("全ての親") or bone.name == StandardBones.get_bone_i("センター") \
				or StandardBones.get_bone_i("左足ＩＫ") or bone.name == StandardBones.get_bone_i("右足ＩＫ"):
			pos *= locomotion_scale
		bone.node.transform.origin = pos + bone.local_position_0
		bone.node.transform.basis = Basis(rot)

func apply_ik_frame(frame: float):
	frame = max(frame, 0.0)
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
			if vmd_skeleton.bones[bone_i].ik_enabled != enable:
				print("%s, %s", name, str(enable))
			vmd_skeleton.bones[bone_i].ik_enabled = enable
