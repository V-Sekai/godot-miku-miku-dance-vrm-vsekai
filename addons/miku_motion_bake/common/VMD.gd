extends Reference

class_name VMD
		
class BoneKeyframe:
	
	class BoneInterp:
		var X: VMDUtilsBake.BezierInterpolator
		var Y: VMDUtilsBake.BezierInterpolator
		var Z: VMDUtilsBake.BezierInterpolator
		var rotation: VMDUtilsBake.BezierInterpolator
		func _init(_X: VMDUtilsBake.BezierInterpolator, _Y: VMDUtilsBake.BezierInterpolator, _Z: VMDUtilsBake.BezierInterpolator, _rotation: VMDUtilsBake.BezierInterpolator):
			X = _X
			Y = _Y
			Z = _Z
			rotation = _rotation
	
	var name: String
	var frame_number: int
	var position: Vector3
	var rotation: Quat
	var interp: BoneInterp
	
	func read(file: File):
		name = VMDUtilsBake.read_string(file, 15)
		frame_number = VMDUtilsBake.unsigned32_to_signed(file.get_32())
		position = VMDUtilsBake.read_vector3(file)
		rotation = VMDUtilsBake.read_quat(file)
		interp = BoneInterp.new(
			VMDUtilsBake.read_bezier(file, 4), VMDUtilsBake.read_bezier(file, 4),
			VMDUtilsBake.read_bezier(file, 4), VMDUtilsBake.read_bezier(file, 4)
		)
		
class FaceKeyframe:
	var name: String
	var frame_number: int
	var weight: float
	
	func read(file: File):
		name = VMDUtilsBake.read_string(file, 15)
		frame_number = file.get_32()
		weight = file.get_float()
		
class CameraKeyframe:
	class CameraInterp:
		var X: VMDUtilsBake.BezierInterpolator
		var Y: VMDUtilsBake.BezierInterpolator
		var Z: VMDUtilsBake.BezierInterpolator
		var R: VMDUtilsBake.BezierInterpolator
		var dist: VMDUtilsBake.BezierInterpolator
		var angle: VMDUtilsBake.BezierInterpolator
	var frame_number: int
	var distance: float
	var position: Vector3
	var rotation: Vector3
	var interp = CameraInterp.new()
	var angle: float
	var perspective: bool
	
	func read(file: File):
		frame_number = VMDUtilsBake.unsigned32_to_signed(file.get_32())
		distance = file.get_float()
		position = VMDUtilsBake.read_vector3(file)
		rotation = VMDUtilsBake.read_vector3(file)
		interp.X = VMDUtilsBake.read_bezier_camera(file, 1)
		interp.Y = VMDUtilsBake.read_bezier_camera(file, 1)
		interp.Z = VMDUtilsBake.read_bezier_camera(file, 1)
		interp.R = VMDUtilsBake.read_bezier_camera(file, 1)
		interp.dist = VMDUtilsBake.read_bezier_camera(file, 1)
		interp.angle = VMDUtilsBake.read_bezier_camera(file, 1)
		angle = VMDUtilsBake.unsigned32_to_signed(file.get_32())
		perspective = file.get_buffer(1)[0] != 0
	
class LightKeyframe:
	var frame_number: int
	var light_color: Color
	var position: Vector3
	
	func read(file: File):
		frame_number = VMDUtilsBake.unsigned32_to_signed(file.get_32())
		light_color = Color(file.get_float(), file.get_float(), file.get_float(), 1.0)
		position = VMDUtilsBake.read_vector3(file)
	
class SelfShadowKeyframe:
	var frame_number: int
	var type: int
	var distance: float
	
	func read(file: File):
		frame_number = VMDUtilsBake.unsigned32_to_signed(file.get_32())
		type = file.get_8()
		distance = file.get_float()

class IKKeyframe:
	var frame_number: int
	var display: bool
	var ik_enable: Dictionary

	func read(file: File):
		frame_number = VMDUtilsBake.unsigned32_to_signed(file.get_32())
		display = bool(file.get_8())
		var ik_enable_count = VMDUtilsBake.unsigned32_to_signed(file.get_32())
		for i in range(ik_enable_count):
			var ik_enable_bone = VMDUtilsBake.read_string(file, 20)
			ik_enable[ik_enable_bone] = bool(file.get_8())


var version: String
var name: String
var bone_keyframes: Array = []
var face_keyframes: Array = []
var camera_keyframes: Array = []
var light_keyframes: Array = []
var self_shadow_keyframes: Array = []
var ik_keyframes: Array = []

func read(file: File) -> int:
	version = VMDUtilsBake.read_string(file, 30)
	name = VMDUtilsBake.read_string(file, 20)

	print("VMD File!\nVersion: %s\nModel: %s" % [version, name])

	if not version.begins_with("Vocaloid Motion Data"):
		printerr("Invalid VMD file")
		return ERR_FILE_CORRUPT

	var bone_frame_count = VMDUtilsBake.unsigned32_to_signed(file.get_32())
	for i in range(bone_frame_count):
		var bk = BoneKeyframe.new()
		bk.read(file)
		bone_keyframes.append(bk)

	if file.get_position() == file.get_len():
		return OK
		
	var face_frame_count = VMDUtilsBake.unsigned32_to_signed(file.get_32())
	for i in range(face_frame_count):
		var fk = FaceKeyframe.new()
		fk.read(file)
		face_keyframes.append(fk)
	
	if file.get_position() == file.get_len():
		return OK
		
	var camera_frame_count = VMDUtilsBake.unsigned32_to_signed(file.get_32())
	for i in range(camera_frame_count):
		var ck = CameraKeyframe.new()
		ck.read(file)
		camera_keyframes.append(ck)
		
	if file.get_position() == file.get_len():
		return OK
		
	var light_frame_count = VMDUtilsBake.unsigned32_to_signed(file.get_32())
	for i in range(light_frame_count):
		var lk = LightKeyframe.new()
		lk.read(file)
		light_keyframes.append(lk)
		
	if file.get_position() == file.get_len():
		return OK
		
	var self_shadow_frame_count = VMDUtilsBake.unsigned32_to_signed(file.get_32())
	for i in range(self_shadow_frame_count):
		var ssk = SelfShadowKeyframe.new()
		ssk.read(file)
		self_shadow_keyframes.append(ssk)
		
	var ik_frame_count = VMDUtilsBake.unsigned32_to_signed(file.get_32())
	for i in range(ik_frame_count):
		var ikk = IKKeyframe.new()
		ikk.read(file)
		ik_keyframes.append(ikk)
		
	return OK
	

