extends Node3D 

class_name VRMAnimator

var skeleton: Skeleton3D

func get_human_scale() -> float:
	var hips_idx = find_humanoid_bone("hips")
	if hips_idx == -1:
		return 0.0
	return skeleton.get_bone_global_rest(hips_idx).origin.y

const MMD_TO_VRM_MORPH = {
	"まばたき": "blink",
	"ウィンク": "blink_l",
	"ウィンク右": "blink_r",
	"あ": "a",
	"い": "i",
	"う": "u",
	"え": "e",
	"お": "o"
}

var vrm: VRMTopLevel

var mesh_idx_to_mesh = []

var mmd_to_godot_bone_map: Dictionary = {}

func _ready():
	assert(get_child_count() > 0, "Must have a VRMTopLevel as the only child")
	assert(get_child(0) is VRMTopLevel, "Must have a VRMTopLevel as the only child")
	vrm = get_child(0)
	skeleton = find_skeleton(vrm)
	assert(skeleton, "VRMTopLevel must contain a Skeleton3D")
	print("VRMAnimator: Skeleton found with ", skeleton.get_bone_count(), " bones and ", skeleton.get_child_count(), " mesh children")
	if vrm.vrm_meta and vrm.vrm_meta.humanoid_bone_mapping:
		print("DEBUG Humanoid bone mapping exists")
		var profile = vrm.vrm_meta.humanoid_bone_mapping.get_profile()
		if profile:
			print("DEBUG Humanoid profile found")
			# Try to print some common bone mappings
			var common_bones = ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"]
			for bone_name in common_bones:
				var mapped = vrm.vrm_meta.humanoid_bone_mapping.get_skeleton_bone_name(bone_name)
				print("DEBUG Humanoid ", bone_name, " -> ", mapped)
		else:
			print("DEBUG No humanoid profile found")
	else:
		print("DEBUG No humanoid bone mapping found")

	# Generate bonemap from MMD names to Godot humanoid names
	for template in StandardBones.bones:
		if template.target != null:
			var mmd_name = StandardBones.get_bone_name(template.name)
			mmd_to_godot_bone_map[mmd_name] = template.target

	var rest_bones : Dictionary
	_fetch_reset_animation(skeleton, rest_bones)
	_fix_skeleton(skeleton, rest_bones)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			mesh_idx_to_mesh.append(child)

func find_skeleton(node: Node) -> Skeleton3D:
	for child in node.get_children():
		if child is Skeleton3D:
			return child
		var found = find_skeleton(child)
		if found:
			return found
	return null

func find_humanoid_bone(bone_name: String) -> int:
	var godot_name = mmd_to_godot_bone_map.get(bone_name, bone_name)
	if vrm.vrm_meta and vrm.vrm_meta.humanoid_bone_mapping:
		var mapped_name = vrm.vrm_meta.humanoid_bone_mapping.get_skeleton_bone_name(godot_name)
		if mapped_name.is_empty():
			# Try capitalized version
			var capitalized = godot_name.capitalize()
			if capitalized != godot_name:
				mapped_name = vrm.vrm_meta.humanoid_bone_mapping.get_skeleton_bone_name(capitalized)
		if not mapped_name.is_empty():
			var bone_idx = skeleton.find_bone(mapped_name)
			if bone_idx != -1:
				return bone_idx
	# Fall back to the original godot name if mapping fails
	var bone_idx = skeleton.find_bone(godot_name)
	if bone_idx == -1:
		# Try additional fallbacks for common mismatches
		var fallback_names = []
		match godot_name:
			"LeftToe":
				fallback_names = ["LeftToes"]
			"RightToe":
				fallback_names = ["RightToes"]
			"LeftThumbIntermediate":
				fallback_names = ["LeftThumbProximal", "LeftThumbDistal"]
			"RightThumbIntermediate":
				fallback_names = ["RightThumbProximal", "RightThumbDistal"]
			_:
				fallback_names = []

		for fallback in fallback_names:
			bone_idx = skeleton.find_bone(fallback)
			if bone_idx != -1:
				return bone_idx

	return bone_idx


func _insert_bone(p_skeleton : Skeleton3D, bone_name : String, rot : Basis, loc : Vector3, r_rest_bones : Dictionary) -> void:
	var rest_bone : Dictionary = {}
	rest_bone["rest_local"] = Transform3D()
	rest_bone["children"] = PackedInt32Array()
	rest_bone["rest_delta"] = rot
	rest_bone["loc"] = loc
	# Store the animation into the RestBone.
	var new_path : String = str(skeleton.get_owner().get_path_to(skeleton)) + ":" + bone_name
	r_rest_bones[new_path] = rest_bone;


func _fetch_reset_animation(p_skel : Skeleton3D, r_rest_bones : Dictionary) -> void:
	var root : Node = p_skel.get_owner()
	if not root:
		return
	if !p_skel:
		return
	for bone in p_skel.get_bone_count():
		_insert_bone(p_skel, p_skel.get_bone_name(bone), Basis(), Vector3(), r_rest_bones)
		
	var right_arm_bone = find_humanoid_bone("RightUpperArm")
	var left_arm_bone = find_humanoid_bone("LeftUpperArm")
	_insert_bone(p_skel, p_skel.get_bone_name(right_arm_bone), Basis(Vector3.FORWARD, deg_to_rad(35)), Vector3(), r_rest_bones)
	_insert_bone(p_skel, p_skel.get_bone_name(left_arm_bone), Basis(Vector3.FORWARD, deg_to_rad(-35)), Vector3(), r_rest_bones)


func _fix_skeleton(p_skeleton : Skeleton3D, r_rest_bones : Dictionary) -> void:
	var bone_count : int = p_skeleton.get_bone_count()
	# First iterate through all the bones and update the RestBone.
	for j in bone_count:
		var final_path : String = str(p_skeleton.get_owner().get_path_to(p_skeleton)) + ":" + p_skeleton.get_bone_name(j)
		var rest_bone = r_rest_bones[final_path]
		rest_bone.rest_local = p_skeleton.get_bone_rest(j)
	for i in bone_count:
		var parent_bone : int = p_skeleton.get_bone_parent(i)
		var path : NodePath = p_skeleton.get_owner().get_path_to(p_skeleton)
		if parent_bone >= 0 and r_rest_bones.has(path):
			r_rest_bones[path]["children"].push_back(i)

	# When we apply transform to a bone, we also have to move all of its children in the opposite direction.
	for i in bone_count:
		var final_path : String = str(p_skeleton.get_owner().get_path_to(p_skeleton)) + String(":") + p_skeleton.get_bone_name(i)
		r_rest_bones[final_path]["rest_local"] = r_rest_bones[final_path]["rest_local"] * Transform3D(r_rest_bones[final_path]["rest_delta"], r_rest_bones[final_path]["loc"])
		# Iterate through the children and move in the opposite direction.
		for j in r_rest_bones[final_path].children.size():
			var child_index : int = r_rest_bones[final_path].children[j]
			var children_path : String = str(p_skeleton.get_name()) + String(":") + p_skeleton.get_bone_name(child_index)
			r_rest_bones[children_path]["rest_local"] = Transform3D(r_rest_bones[final_path]["rest_delta"], r_rest_bones[final_path]["loc"]).affine_inverse() * r_rest_bones[children_path]["rest_local"]

	for i in bone_count:
		var final_path : String = str(p_skeleton.get_owner().get_path_to(p_skeleton)) + ":" + p_skeleton.get_bone_name(i)
		if !r_rest_bones.has(final_path):
			continue
		var rest_transform : Transform3D  = r_rest_bones[final_path]["rest_local"]
		p_skeleton.set_bone_rest(i, rest_transform)

func set_blend_shape_value(blend_shape_name: String, value: float):
	var meta = vrm.vrm_meta
	var new_bs_name = ""
	if blend_shape_name in MMD_TO_VRM_MORPH:
		blend_shape_name = MMD_TO_VRM_MORPH[blend_shape_name]
		if not meta.get("blend_shape_groups"):
			return
		var group = meta.blend_shape_groups[blend_shape_name]
		for bind in group.binds:
			if bind.mesh < mesh_idx_to_mesh.size():
				var weight = 0.99999 * float(bind.weight) / 100.0
				var mesh := mesh_idx_to_mesh[bind.mesh] as MeshInstance3D
				mesh.set("blend_shapes/morph_%d" % [bind.index], value * weight)
