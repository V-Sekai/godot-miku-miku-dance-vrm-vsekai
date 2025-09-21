extends Node3D

class_name VMDCameraController

const FPS := 30.0

var camera: Camera3D
var motion: Motion
var anim_scale: float = 0.07

func setup_camera(animator: Node, motion_data: Motion):
	motion = motion_data
	if not motion:
		return

	# Handle camera
	if camera:
		camera.queue_free()
	if motion.camera.keyframes.size() > 0:
		camera = Camera3D.new()
		animator.add_child(camera)
		camera.owner = animator.owner
		camera.make_current()

func apply_camera_frame(frame: float):
	if not camera or not motion:
		return

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
