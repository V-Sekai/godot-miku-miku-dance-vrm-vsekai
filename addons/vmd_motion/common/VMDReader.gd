class_name VMDReader

## Pure VMD file parsing utility
## No dependencies on Godot nodes or scenes

static func load_file(path: String) -> VMDData:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open VMD file: ", path)
		return null

	var vmd = VMD.new()
	var err = vmd.read(file)
	if err != OK:
		push_error("Failed to parse VMD file: ", err)
		return null

	return _convert_to_data(vmd)

static func _convert_to_data(vmd: VMD) -> VMDData:
	var data = VMDData.new()
	data.version = vmd.version
	data.name = vmd.name
	data.bone_keyframes = vmd.bone_keyframes.duplicate()
	data.face_keyframes = vmd.face_keyframes.duplicate()
	data.camera_keyframes = vmd.camera_keyframes.duplicate()
	return data

# Test helper - create mock VMD data
static func create_test_data() -> VMDData:
	var data = VMDData.new()
	data.version = "Vocaloid Motion Data 0002"
	data.name = "Test Model"

	# Add a test bone keyframe
	var keyframe = VMD.BoneKeyframe.new()
	keyframe.name = "頭"  # Head in Japanese
	keyframe.frame_number = 0
	keyframe.position = Vector3(0, 0.1, 0)
	keyframe.rotation = Quaternion.IDENTITY
	data.bone_keyframes.append(keyframe)

	return data

class VMDData:
	var version: String
	var name: String
	var bone_keyframes: Array[VMD.BoneKeyframe]
	var face_keyframes: Array[VMD.FaceKeyframe]
	var camera_keyframes: Array[VMD.CameraKeyframe]

	func _init():
		bone_keyframes = []
		face_keyframes = []
		camera_keyframes = []

	func get_bone_keyframes_for_bone(bone_name: String) -> Array[VMD.BoneKeyframe]:
		var result: Array[VMD.BoneKeyframe] = []
		for kf in bone_keyframes:
			if kf.name == bone_name:
				result.append(kf)
		return result

	func get_max_frame() -> int:
		var max_frame = 0
		for kf in bone_keyframes:
			max_frame = max(max_frame, kf.frame_number)
		for kf in face_keyframes:
			max_frame = max(max_frame, kf.frame_number)
		return max_frame
