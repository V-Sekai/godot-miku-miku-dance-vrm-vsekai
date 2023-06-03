extends Reference

class_name VMD
		
class BoneKeyframe:
	
	class BoneInterp:
		var X: VMDUtils.BezierInterpolator
		var Y: VMDUtils.BezierInterpolator
		var Z: VMDUtils.BezierInterpolator
		var rotation: VMDUtils.BezierInterpolator
		func _init(_X: VMDUtils.BezierInterpolator, _Y: VMDUtils.BezierInterpolator, _Z: VMDUtils.BezierInterpolator, _rotation: VMDUtils.BezierInterpolator):
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
		name = VMDUtils.read_string(file, 15)
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		position = VMDUtils.read_vector3(file)
		rotation = VMDUtils.read_quat(file)
		interp = BoneInterp.new(
			VMDUtils.read_bezier(file, 4), VMDUtils.read_bezier(file, 4),
			VMDUtils.read_bezier(file, 4), VMDUtils.read_bezier(file, 4)
		)
		
class FaceKeyframe:
	var name: String
	var frame_number: int
	var weight: float
	
	func read(file: File):
		name = VMDUtils.read_string(file, 15)
		frame_number = file.get_32()
		weight = file.get_float()
		
class CameraKeyframe:
	class CameraInterp:
		var X: VMDUtils.BezierInterpolator
		var Y: VMDUtils.BezierInterpolator
		var Z: VMDUtils.BezierInterpolator
		var R: VMDUtils.BezierInterpolator
		var dist: VMDUtils.BezierInterpolator
		var angle: VMDUtils.BezierInterpolator
	var frame_number: int
	var distance: float
	var position: Vector3
	var rotation: Vector3
	var interp = CameraInterp.new()
	var angle: float
	var perspective: bool
	
	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		distance = file.get_float()
		position = VMDUtils.read_vector3(file)
		rotation = VMDUtils.read_vector3(file)
		interp.X = VMDUtils.read_bezier_camera(file, 1)
		interp.Y = VMDUtils.read_bezier_camera(file, 1)
		interp.Z = VMDUtils.read_bezier_camera(file, 1)
		interp.R = VMDUtils.read_bezier_camera(file, 1)
		interp.dist = VMDUtils.read_bezier_camera(file, 1)
		interp.angle = VMDUtils.read_bezier_camera(file, 1)
		angle = VMDUtils.unsigned32_to_signed(file.get_32())
		perspective = file.get_buffer(1)[0] != 0
	
class LightKeyframe:
	var frame_number: int
	var light_color: Color
	var position: Vector3
	
	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		light_color = Color(file.get_float(), file.get_float(), file.get_float(), 1.0)
		position = VMDUtils.read_vector3(file)
	
class SelfShadowKeyframe:
	var frame_number: int
	var type: int
	var distance: float
	
	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		type = file.get_8()
		distance = file.get_float()

class IKKeyframe:
	var frame_number: int
	var display: bool
	var ik_enable: Dictionary

	func read(file: File):
		frame_number = VMDUtils.unsigned32_to_signed(file.get_32())
		display = bool(file.get_8())
		var ik_enable_count = VMDUtils.unsigned32_to_signed(file.get_32())
		for i in range(ik_enable_count):
			var ik_enable_bone = VMDUtils.read_string(file, 20)
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
	version = VMDUtils.read_string(file, 30)
	name = VMDUtils.read_string(file, 20)

	print("VMD File!\nVersion: %s\nModel: %s" % [version, name])

	if not version.begins_with("Vocaloid Motion Data"):
		printerr("Invalid VMD file")
		return ERR_FILE_CORRUPT

	var bone_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(bone_frame_count):
		var bk = BoneKeyframe.new()
		bk.read(file)
		bone_keyframes.append(bk)

	if file.get_position() == file.get_len():
		return OK
		
	var face_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(face_frame_count):
		var fk = FaceKeyframe.new()
		fk.read(file)
		face_keyframes.append(fk)
	
	if file.get_position() == file.get_len():
		return OK
		
	var camera_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(camera_frame_count):
		var ck = CameraKeyframe.new()
		ck.read(file)
		camera_keyframes.append(ck)
		
	if file.get_position() == file.get_len():
		return OK
		
	var light_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(light_frame_count):
		var lk = LightKeyframe.new()
		lk.read(file)
		light_keyframes.append(lk)
		
	if file.get_position() == file.get_len():
		return OK
		
	var self_shadow_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(self_shadow_frame_count):
		var ssk = SelfShadowKeyframe.new()
		ssk.read(file)
		self_shadow_keyframes.append(ssk)
		
	var ik_frame_count = VMDUtils.unsigned32_to_signed(file.get_32())
	for i in range(ik_frame_count):
		var ikk = IKKeyframe.new()
		ikk.read(file)
		ik_keyframes.append(ikk)
		
	return OK
	

