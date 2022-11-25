# This should be added to autoloads...
extends Node

const BONE_NAMES = [
	"全ての親", "センター", "グルーブ",
	"左足IK親", "左足ＩＫ", "左つま先ＩＫ",
	"右足IK親", "右足ＩＫ", "右つま先ＩＫ",
	"腰", "下半身", "上半身", "上半身2", "首", "頭",
	"左目", "右目", "両目",
	"左肩P", "左肩", "左肩C", "左腕", "左腕捩", "左ひじ", "左手捩", "左手首",
	"右肩P", "右肩", "右肩C", "右腕", "右腕捩", "右ひじ", "右手捩", "右手首",
	"左足", "左ひざ", "左足首", "左つま先",
	"右足", "右ひざ", "右足首", "右つま先",
	"左足D", "左ひざD", "左足首D", "左足先EX",
	"右足D", "右ひざD", "右足首D", "右足先EX",
	"左親指０", "左親指１", "左親指２", "左人指１", "左人指２", "左人指３",
	"左中指１", "左中指２", "左中指３", "左薬指１", "左薬指２", "左薬指３", "左小指１", "左小指２", "左小指３",
	"右親指０", "右親指１", "右親指２", "右人指１", "右人指２", "右人指３",
	"右中指１", "右中指２", "右中指３", "右薬指１", "右薬指２", "右薬指３", "右小指１", "右小指２", "右小指３",
]

const MIRROR_BONE_NAMES = [
	"全ての親", "センター", "グルーブ",
	"右足IK親", "右足ＩＫ", "右つま先ＩＫ",
	"左足IK親", "左足ＩＫ", "左つま先ＩＫ",
	"腰", "下半身", "上半身", "上半身2", "首", "頭",
	"右目", "左目", "両目",
	"右肩P", "右肩", "右肩C", "右腕", "右腕捩", "右ひじ", "右手捩", "右手首",
	"左肩P", "左肩", "左肩C", "左腕", "左腕捩", "左ひじ", "左手捩", "左手首",
	"右足", "右ひざ", "右足首", "右つま先",
	"左足", "左ひざ", "左足首", "左つま先",
	"右足D", "右ひざD", "右足首D", "右足先EX",
	"左足D", "左ひざD", "左足首D", "左足先EX",
	"右親指０", "右親指１", "右親指２", "右人指１", "右人指２", "右人指３",
	"右中指１", "右中指２", "右中指３", "右薬指１", "右薬指２", "右薬指３", "右小指１", "右小指２", "右小指３",
	"左親指０", "左親指１", "左親指２", "左人指１", "左人指２", "左人指３",
	"左中指１", "左中指２", "左中指３", "左薬指１", "左薬指２", "左薬指３", "左小指１", "左小指２", "左小指３"
]

var bone_names = {}
var mirror_bone_names = {}

var bones = []
var constraints = []

func get_bone_i(bone_name: String) -> int:
	return bone_names.get(bone_name, -1)
	
func get_bone_name(bone_i: int):
	return BONE_NAMES[bone_i]

func _init():
	var i = 0
	for bone_name in BONE_NAMES:
		bone_names[bone_name] = i
		i += 1
	
	for bone_name in MIRROR_BONE_NAMES:
		mirror_bone_names[bone_name] = get_bone_i(bone_name)
	
	bones = [
		StandardBone.new(get_bone_i("全ての親"), null, null, null),
		StandardBone.new(get_bone_i("センター"), get_bone_i("全ての親"), "spine", null),
		StandardBone.new(get_bone_i("グルーブ"), get_bone_i("センター"), null, null),
		StandardBone.new(get_bone_i("腰"), get_bone_i("グルーブ"), null, null),
		StandardBone.new(get_bone_i("下半身"), get_bone_i("腰"), "spine", "hips"),
		StandardBone.new(get_bone_i("上半身"), get_bone_i("腰"), "spine", "spine"),
		StandardBone.new(get_bone_i("上半身2"), get_bone_i("上半身"), "chest", "chest"),
		StandardBone.new(get_bone_i("首"), get_bone_i("上半身2"), "neck", "neck"),
		StandardBone.new(get_bone_i("頭"), get_bone_i("首"), "head", "head"),
		StandardBone.new(get_bone_i("両目"), get_bone_i("頭"), null, null),
		StandardBone.new(get_bone_i("左目"), get_bone_i("頭"), "leftEye", "leftEye"),
		StandardBone.new(get_bone_i("右目"), get_bone_i("頭"), "rightEye", "rightEye"),
		
		StandardBone.new(get_bone_i("左肩P"), get_bone_i("上半身2"), "leftShoulder", null),
		StandardBone.new(get_bone_i("左肩"), get_bone_i("左肩P"), null, "leftShoulder"),
		StandardBone.new(get_bone_i("左肩C"), get_bone_i("左肩"), "leftUpperArm", null),
		StandardBone.new(get_bone_i("左腕"), get_bone_i("左肩C"), null, "leftUpperArm"),
		StandardBone.new(get_bone_i("左腕捩"), get_bone_i("左腕"), "leftLowerArm", null),
		StandardBone.new(get_bone_i("左ひじ"), get_bone_i("左腕捩"), null, "leftLowerArm"),
		StandardBone.new(get_bone_i("左手捩"), get_bone_i("左ひじ"), "leftHand", null),
		StandardBone.new(get_bone_i("左手首"), get_bone_i("左手捩"), null, "leftHand"),
		
		StandardBone.new(get_bone_i("右肩P"), get_bone_i("上半身2"), "rightShoulder", null),
		StandardBone.new(get_bone_i("右肩"), get_bone_i("右肩P"), null, "rightShoulder"),
		StandardBone.new(get_bone_i("右肩C"), get_bone_i("右肩"), "rightUpperArm", null),
		StandardBone.new(get_bone_i("右腕"), get_bone_i("右肩C"), null, "rightUpperArm"),
		StandardBone.new(get_bone_i("右腕捩"), get_bone_i("右腕"), "rightLowerArm", null),
		StandardBone.new(get_bone_i("右ひじ"), get_bone_i("右腕捩"), null, "rightLowerArm"),
		StandardBone.new(get_bone_i("右手捩"), get_bone_i("右ひじ"), "rightHand", null),
		StandardBone.new(get_bone_i("右手首"), get_bone_i("右手捩"), null, "rightHand"),
		
		StandardBone.new(get_bone_i("左足IK親"), get_bone_i("全ての親"), "leftFoot", null),
		StandardBone.new(get_bone_i("左足ＩＫ"), get_bone_i("左足IK親"), null, null),
		StandardBone.new(get_bone_i("左つま先ＩＫ"), get_bone_i("左足ＩＫ"), "leftToes", null),
		StandardBone.new(get_bone_i("左足"), get_bone_i("下半身"), "leftUpperLeg", null),
		StandardBone.new(get_bone_i("左足D"), get_bone_i("下半身"), "leftUpperLeg", "leftUpperLeg"),
		StandardBone.new(get_bone_i("左ひざ"), get_bone_i("左足"), "leftLowerLeg", null),
		StandardBone.new(get_bone_i("左ひざD"), get_bone_i("左足D"), "leftLowerLeg", "leftLowerLeg"),
		StandardBone.new(get_bone_i("左足首"), get_bone_i("左ひざ"), "leftFoot", null),
		StandardBone.new(get_bone_i("左足首D"), get_bone_i("左ひざD"), "leftFoot", "leftFoot"),
		StandardBone.new(get_bone_i("左つま先"), get_bone_i("左足首"), "leftToes", null),
		StandardBone.new(get_bone_i("左足先EX"), get_bone_i("左足首D"), "leftToes", "leftToes"),
		
		StandardBone.new(get_bone_i("右足IK親"), get_bone_i("全ての親"), "rightFoot", null),
		StandardBone.new(get_bone_i("右足ＩＫ"), get_bone_i("右足IK親"), null, null),
		StandardBone.new(get_bone_i("右つま先ＩＫ"), get_bone_i("右足ＩＫ"), "rightToes", null),
		StandardBone.new(get_bone_i("右足"), get_bone_i("下半身"), "rightUpperLeg", null),
		StandardBone.new(get_bone_i("右足D"), get_bone_i("下半身"), "rightUpperLeg", "rightUpperLeg"),
		StandardBone.new(get_bone_i("右ひざ"), get_bone_i("右足"), "rightLowerLeg", null),
		StandardBone.new(get_bone_i("右ひざD"), get_bone_i("右足D"), "rightLowerLeg", "rightLowerLeg"),
		StandardBone.new(get_bone_i("右足首"), get_bone_i("右ひざ"), "rightFoot", null),
		StandardBone.new(get_bone_i("右足首D"), get_bone_i("右ひざD"), "rightFoot", "rightFoot"),
		StandardBone.new(get_bone_i("右つま先"), get_bone_i("右足首"), "rightToes", null),
		StandardBone.new(get_bone_i("右足先EX"), get_bone_i("右足首D"), "rightToes", "rightToes")
	]
	
	var finger_bone_groups = [
		[get_bone_i("左手首"), get_bone_i("左親指０"), get_bone_i("左親指１"), get_bone_i("左親指２"), "leftThumbProximal",  "leftThumbIntermediate",  "leftThumbDistal"],
		[get_bone_i("左手首"), get_bone_i("左人指１"), get_bone_i("左人指２"), get_bone_i("左人指３"), "leftIndexProximal",  "leftIndexIntermediate",  "leftIndexDistal"],
		[get_bone_i("左手首"), get_bone_i("左中指１"), get_bone_i("左中指２"), get_bone_i("左中指３"), "leftMiddleProximal", "leftMiddleIntermediate", "leftMiddleDistal"],
		[get_bone_i("左手首"), get_bone_i("左薬指１"), get_bone_i("左薬指２"), get_bone_i("左薬指３"), "leftRingProximal",   "leftRingIntermediate",   "leftRingDistal"],
		[get_bone_i("左手首"), get_bone_i("左小指１"), get_bone_i("左小指２"), get_bone_i("左小指３"), "leftLittleProximal", "leftLittleIntermediate", "leftLittleDistal"],
		[get_bone_i("右手首"), get_bone_i("右親指０"), get_bone_i("右親指１"), get_bone_i("右親指２"), "rightThumbProximal",  "rightThumbIntermediate",  "rightThumbDistal"],
		[get_bone_i("右手首"), get_bone_i("右人指１"), get_bone_i("右人指２"), get_bone_i("右人指３"), "rightIndexProximal",  "rightIndexIntermediate",  "rightIndexDistal"],
		[get_bone_i("右手首"), get_bone_i("右中指１"), get_bone_i("右中指２"), get_bone_i("右中指３"), "rightMiddleProximal", "rightMiddleIntermediate", "rightMiddleDistal"],
		[get_bone_i("右手首"), get_bone_i("右薬指１"), get_bone_i("右薬指２"), get_bone_i("右薬指３"), "rightRingProximal",   "rightRingIntermediate",   "rightRingDistal"],
		[get_bone_i("右手首"), get_bone_i("右小指１"), get_bone_i("右小指２"), get_bone_i("右小指３"), "rightLittleProximal", "rightLittleIntermediate", "rightLittleDistal"],
	]

	var finger_bones = []

	for group in finger_bone_groups:
		var finger_group = [
			StandardBone.new(group[1], group[0], group[4], group[4]),
			StandardBone.new(group[2], group[1], group[5], group[5]),
			StandardBone.new(group[3], group[2], group[6], group[6])
		]
		
		finger_bones += finger_group
	
	bones += finger_bones
	
	constraints = [
		RotAdd.new(get_bone_i("左目"), get_bone_i("両目")),
		RotAdd.new(get_bone_i("右目"), get_bone_i("両目")),
		RotAdd.new(get_bone_i("左肩C"), get_bone_i("左肩P"), true),
		RotAdd.new(get_bone_i("右肩C"), get_bone_i("右肩P"), true),
		
		LimbIK.new(get_bone_i("左足ＩＫ"), get_bone_i("左足"), get_bone_i("左ひざ"), get_bone_i("左足首")),
		LookAt.new(get_bone_i("左足ＩＫ"), get_bone_i("左つま先ＩＫ"), get_bone_i("左足首"), get_bone_i("左つま先")),
		RotAdd.new(get_bone_i("左足D"), get_bone_i("左足")),
		RotAdd.new(get_bone_i("左ひざD"), get_bone_i("左ひざ")),
		RotAdd.new(get_bone_i("左足首D"), get_bone_i("左足首")),
		
		LimbIK.new(get_bone_i("右足ＩＫ"), get_bone_i("右足"), get_bone_i("右ひざ"), get_bone_i("右足首")),
		LookAt.new(get_bone_i("右足ＩＫ"), get_bone_i("右つま先ＩＫ"), get_bone_i("右足首"), get_bone_i("右つま先")),
		RotAdd.new(get_bone_i("右足D"), get_bone_i("右足")),
		RotAdd.new(get_bone_i("右ひざD"), get_bone_i("右ひざ")),
		RotAdd.new(get_bone_i("右足首D"), get_bone_i("右足首")),
	]

static func fix_bone_name(bone_name: String) -> String:
	return bone_name.replace("捩れ", "捩").replace("捻", "捩")

class StandardBone:
	var name: int
	var parent#: int
	var source#: String
	var target#: String

	func _init(_name: int,_parent,_source,_target):
		name = _name
		parent = _parent
		source = _source
		target = _target

class Constraint:
	pass
	
class RotAdd:
	extends Constraint
	
	var target: int
	var source: int
	var minus: bool
	
	func _init(_target: int,_source: int,_minus := false):
		target = _target
		source = _source
		minus = _minus

class LimbIK:
	extends Constraint
	
	var source: int
	var target_0: int
	var target_1: int
	var target_2: int
	
	func _init(_source: int,_target_0: int,_target_1: int,_target_2: int):
		source = _source
		target_0 = _target_0
		target_1 = _target_1
		target_2 = _target_2

class LookAt:
	extends Constraint
	
	var source_0: int
	var source_1: int
	var target_0: int
	var target_1: int
	
	func _init(_source_0,_source_1,_target_0,_target_1):
		source_0 = _source_0
		source_1 = _source_1
		target_0 = _target_0
		target_1 = _target_1
