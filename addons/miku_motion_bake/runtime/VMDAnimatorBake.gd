extends Node3D

class_name VRMAnimatorBake

const MMD_TO_VRM_MorphBake = {
	"まばたき": "blink",
	"ウィンク": "blink_l",
	"ウィンク右": "blink_r",
	"あ": "a",
	"い": "i",
	"う": "u",
	"え": "e",
	"お": "o"
}


var mesh_idx_to_mesh = []

var skeleton: Skeleton3D

var vrm: VRMTopLevel
var rest_bones : Dictionary

func _ready():
	if not get_child_count() > 0: #,"Must have a VRMTopLevel as the only child")
		assert(0)
	if not (get_child(0) as VRMTopLevel): #,"Must have a VRMTopLevel as the only child")
		assert(0)
	vrm = get_child(0)
	skeleton = vrm.get_node(vrm.vrm_skeleton) as Skeleton3D
	_fetch_reset_animation(skeleton, rest_bones)	
	_fix_skeleton(skeleton, rest_bones)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			mesh_idx_to_mesh.append(child)

	
func get_human_scale() -> float:
	return VMDUtilsBake.get_bone_global_rest(skeleton, find_humanoid_bone("hips")).origin.y


func find_humanoid_bone(bone_name: String):
	if not vrm:
		return -1
	if vrm.vrm_meta and vrm.vrm_meta.humanoid_bone_mapping.has(bone_name):
		var skeletal_bone_name : String = vrm.vrm_meta.humanoid_bone_mapping[bone_name]
		return skeleton.find_bone(skeletal_bone_name)
	else:
		return skeleton.find_bone(bone_name)


func _insert_bone(p_skeleton : Skeleton3D, bone_name : String, rot : Basis, loc : Vector3, r_rest_bones : Dictionary) -> void:
	var rest_bone : Dictionary = {}	
	rest_bone["rest_local"] = Transform3D()
	rest_bone["children"] = PackedInt32Array()
	var rot_basis : Basis = rot
	rot_basis = rot_basis.scaled(scale)
	rest_bone["rest_delta"] = rot 
	rest_bone["loc"] = loc
	# Store the animation into the RestBone.
	var new_path : String = str(skeleton.get_owner().get_path_to(skeleton)) + ":" + bone_name
	rest_bone["rest_original"] = skeleton.get_bone_rest(skeleton.find_bone(bone_name))
	r_rest_bones[new_path] = rest_bone;


func _fetch_reset_animation(p_skel : Skeleton3D, r_rest_bones : Dictionary) -> void:
	var root : Node = p_skel.get_owner()
	if not root:
		return
	if !p_skel:
		return
	for bone in p_skel.get_bone_count():
		_insert_bone(p_skel, p_skel.get_bone_name(bone), Basis(), Vector3(), r_rest_bones)
		
	var right_arm_bone = find_humanoid_bone("rightUpperArm")
	var left_arm_bone = find_humanoid_bone("leftUpperArm")
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
		if parent_bone == -1:
			continue
		var final_path : String = str(path) + ":" + p_skeleton.get_bone_name(parent_bone)
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
	if blend_shape_name in MMD_TO_VRM_MorphBake:
		blend_shape_name = MMD_TO_VRM_MorphBake[blend_shape_name]		
		var group = meta.blend_shape_groups[blend_shape_name]
		for bind in group.binds:
			if bind.mesh < mesh_idx_to_mesh.size():
				var weight = 0.99999 * float(bind.weight) / 100.0
				var mesh := mesh_idx_to_mesh[bind.mesh] as MeshInstance3D
				mesh.set("blend_shapes/Morph_%d" % [bind.index], value * weight)
