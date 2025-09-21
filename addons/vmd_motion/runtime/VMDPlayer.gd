extends Node3D

const FPS := 30.0

@export_file("*.vmd")
var starting_file_path: String
@export_node_path
var animator_path: NodePath
@onready
var animator: VRMAnimator = get_node(animator_path)
var camera_controller: VMDCameraController
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

	# Fix bone names
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

	# Create and setup the VMD modifier
	if not vmd_modifier:
		var modifier_script = load("res://addons/vmd_motion/runtime/VMDSkeletonModifier3D.gd")
		vmd_modifier = modifier_script.new()
		# Add modifier as child of the skeleton, not the animator
		if animator and animator.skeleton:
			animator.skeleton.add_child(vmd_modifier)
			vmd_modifier.owner = animator.owner

	# Configure the modifier
	vmd_modifier.set_motion(motion)
	vmd_modifier.anim_scale = anim_scale
	vmd_modifier.mirror = mirror
	vmd_modifier.locomotion_scale = locomotion_scale
	vmd_modifier.enable_ik = enable_ik
	vmd_modifier.enable_ikq = enable_ikq
	vmd_modifier.enable_shape = enable_shape

	if motion:
		set_process(true)
		start_time = Time.get_ticks_msec()

		# Initialize camera controller
		if not camera_controller:
			camera_controller = VMDCameraController.new()
			add_child(camera_controller)
		camera_controller.anim_scale = anim_scale
		camera_controller.setup_camera(animator, motion)

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
	if not starting_file_path.is_empty():
		load_motions([starting_file_path])

func _process(delta):
	if not manual_update_time:
		time = (Time.get_ticks_msec() - start_time) / 1000.0
	current_frame = time * FPS
	if vmd_modifier:
		vmd_modifier.set_frame(current_frame)
		# Connect to modification_processed to handle post-modification tasks
		if not vmd_modifier.is_connected("modification_processed", _on_vmd_modification_processed):
			vmd_modifier.connect("modification_processed", _on_vmd_modification_processed)

func _on_vmd_modification_processed():
	# Handle camera animation after VMD modifications are complete
	if camera_controller:
		camera_controller.apply_camera_frame(current_frame)
