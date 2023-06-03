extends Node3D

class_name VMDPlayer

const FPS := 30.0

@export_file("*.vmd") 
var starting_file_path: String
@export_node_path
var animator_path: NodePath
@onready
var camera: Camera3D
@onready
var animator: VMDAnimatorBase = get_node(animator_path)
@export
var anim_scale := 0.08
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

var start_time: int
var scale_overrides = PackedFloat32Array()
var time = 0.0
var motion: Motion
var bone_curves = []
var vmd_skeleton: VMDSkeleton
var apply_ikq = false
var morph: Morph
var first_frame_number: int
var max_frame: int

func vmd_from_file(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
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
#	var bone_frames_str = PoolStringArray()
#	bone_frames_str.resize(motion.bones.size())
#	for i in motion.bones.size():
#		var curve = motion.bones.values()[i] as Motion.BoneCurve
#		bone_frames_str.set(i, "%s (%d)" % [motion.bones.keys()[i], curve.keyframes.size()])
#	print_debug("Bone frames: ", bone_frames_str.join(", "))
	
#	var face_frames_str = PoolStringArray()
#	face_frames_str.resize(motion.faces.size())
#	for i in motion.faces.size():
#		var curve = motion.faces.values()[i] as Motion.FaceCurve
#		face_frames_str.set(i, "%s (%d)" % [motion.faces.keys()[i], curve.keyframes.size()])
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
			if keyframe.rotation != Quaternion.IDENTITY:
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
		start_time = Time.get_ticks_msec()
		if camera:
			camera.queue_free()
		if motion.camera.keyframes.size() > 0:
			camera = Camera3D.new()
			animator.add_child(camera)
			camera.owner = animator.owner
			camera.make_current()


func _ready():
	animator = get_node(animator_path)
	set_process(false)
	if not starting_file_path.is_empty():
		load_motions([starting_file_path])


func _process(delta):
	if not manual_update_time:
		time = (Time.get_ticks_msec() - start_time) / 1000.0
	var frame = time * FPS
	update_frame(frame)


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
	var target_pos = camera_sample.position
	var quat = Quaternion.IDENTITY
	var rot = camera_sample.rotation
	quat.set_euler(rot)
	var camera_pos = target_pos
	target_pos.z *= -1
	camera.global_transform.basis = Basis(quat)
	camera.global_transform.origin = (target_pos + (quat * Vector3.FORWARD) * camera_sample.distance) * anim_scale

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

var last_ik_enable = {}

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
