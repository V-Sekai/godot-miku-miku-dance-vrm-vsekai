class_name VMDSkeletonBake

class VMDSkelBone:
	var name: int
	var node: Spatial
	var local_position_0: Vector3
	
	var target = null
	var target_position: Vector3
	var target_rotation: Quat
	
	var skeleton: Skeleton
	
	var ik_enabled: bool
	var target_bone_skel_i: int
	
	# source: transform
	# _target: transform
	func _init(_name: int, parent_node: Spatial, source, _target, skel: Skeleton, _target_bone_skel_i: int):
		name = _name
		skeleton = skel
		target_bone_skel_i = _target_bone_skel_i
		
		node = Spatial.new()
		node.name = StandardBones.get_bone_name(name)
		parent_node.add_child(node)
		
		if source is Transform:
			node.global_transform.origin = source.origin
		local_position_0 = node.transform.origin
		
		if _target is Transform:
			target = _target
			target_position = node.global_transform.xform_inv(target.origin)
			target_rotation = node.global_transform.basis.get_rotation_quat().inverse() * target.basis.get_rotation_quat()
	func apply_target():
		if target != null:
			target.origin = node.global_transform.xform(target_position)
			target.basis = Basis(node.global_transform.basis.get_rotation_quat() * target_rotation)
			update_pose()
	func update_pose():
		if skeleton == null:
			return
		if target_bone_skel_i == -1:
			return
		skeleton.set_bone_global_pose_override(target_bone_skel_i, target, 1.0, true)
		
var root: Spatial
var bones = []
	
class VMDSkelBonePlaceHolder:
	pass
	
func _init(animator: VRMAnimatorBake, root_override = null, source_overrides := {}):
	root = Spatial.new()
	var skel := animator.skeleton
	if not root_override:
		skel.add_child(root)
	else:
		root_override.add_child(root)
	root.global_transform.basis.x = Vector3.LEFT
	for i in range(StandardBones.bone_names.size()):
		bones.append(VMDSkelBonePlaceHolder.new())
	
	
	for i in range(StandardBones.bones.size()):
		var template = StandardBones.bones[i] as StandardBones.StandardBone
		var parent_node = root if not template.parent else bones[template.parent].node
		var source_bone_skel_i = -1
		var target_bone_skel_i = -1
	
		var source_transform = null
		
		if template.source:
			source_bone_skel_i = animator.find_humanoid_bone(template.source)
			source_transform = VMDUtilsBake.get_bone_global_rest(skel, source_bone_skel_i)
		if template.target:
			target_bone_skel_i = animator.find_humanoid_bone(template.target)
		
		var position_transform = source_overrides[template.name] if template.parent in source_overrides else source_transform
		var target = null if template.target == null else VMDUtilsBake.get_bone_global_rest(skel, target_bone_skel_i)
		bones[template.name] = VMDSkelBone.new(template.name, parent_node, position_transform, target, skel, target_bone_skel_i)
		
	# TODO: juice this
	
	for i in range(bones.size()):
		var bone = bones[i]
		if bone is VMDSkelBonePlaceHolder:
			bones[i] = VMDSkelBone.new(i, root, null, null, skel, animator.find_humanoid_bone(StandardBones.bones[i].target))

func apply_targets():
	for i in range(bones.size()):
		var bone = bones[i] as VMDSkelBone
		bone.apply_target()
		
func apply_constraints(apply_ik = true, apply_ikq = false):
	for i in range(StandardBones.constraints.size()):
		var constraint = StandardBones.constraints[i] as StandardBones.Constraint
		
		if constraint is StandardBones.RotAdd:
			var target = (bones[constraint.target] as VMDSkelBone).node
			var source = (bones[constraint.source] as VMDSkelBone).node
			
			if constraint.minus:
				target.global_transform.basis = source.get_parent().global_transform.basis * source.global_transform.basis.inverse() * target.global_transform.basis
			else:
				target.transform.basis = source.transform.basis * target.transform.basis
		elif constraint is StandardBones.LimbIK:
			var upper_leg = bones[constraint.target_0].node as Spatial
			var lower_leg = bones[constraint.target_1].node as Spatial
			var foot = bones[constraint.target_2].node as Spatial
			var foot_ik = bones[constraint.source] as VMDSkelBone
			
			if not foot_ik.ik_enabled:
				continue
			var local_target := upper_leg.global_transform.xform_inv(foot_ik.node.global_transform.origin) as Vector3
			var bend := -calc_bend(lower_leg.transform.origin, foot.transform.origin, local_target.length())
			lower_leg.transform.basis = Basis(Quat(sin(bend/2.0), 0, 0, cos(bend/2.0)))
			var upper_leg_local_rot := upper_leg.transform.basis.get_rotation_quat() as Quat
			var from = upper_leg.global_transform.xform_inv(foot.global_transform.origin)
			var to = local_target
			upper_leg.transform.basis = Basis(upper_leg.transform.basis.get_rotation_quat() * quat_from_to_rotation(from, to))
		elif constraint is StandardBones.LookAt:
			var foot = bones[constraint.target_0].node as Spatial
			var toe = bones[constraint.target_1].node as Spatial
			var foot_ik = null if not constraint.source_0 else bones[constraint.source_0]
			var toe_ik = null if not constraint.source_1 else bones[constraint.source_1]
			
			if foot_ik != null and !foot_ik.ik_enabled:
				continue
			if foot_ik != null and apply_ikq:
				foot.global_transform.basis = foot_ik.node.global_transform.basis
			if toe_ik.ik_enabled:
				var basis : Basis = quat_from_to_rotation(toe.transform.origin, foot.global_transform.xform_inv(toe_ik.node.global_transform.origin))
				foot.global_transform.basis *= basis


static func calc_bend(v0: Vector3, v1: Vector3, dist: float) -> float:
		var u0 = Vector2(v0.y, v0.z);
		var u1 = Vector2(v1.y, v1.z);
		var dot = (dist*dist - v0.length_squared() - v1.length_squared())/2 - v0.x*v1.x;
		u1 = Vector2(u0.x*u1.x + u0.y*u1.y, u0.x*u1.y - u1.x*u0.y);
		return max(0.0, acos(clamp(dot/u1.length(), -1, 1)) - atan2(u1.y, u1.x));
			
# Ported from Ogre3D
func quat_from_to_rotation(from: Vector3, to: Vector3) -> Quat:
	from = from.normalized()
	to = to.normalized()
	var q = Quat()
	var d = from.dot(to)
	if d >= 1.0:
		return Quat.IDENTITY
	elif d < (1.0e-6 - 1.0):
		var axis = Vector3.RIGHT.cross(from)
		if axis.length_squared() < (1e-06 * 1e-06):
			axis = Vector3.UP.cross(from)
		q.set_axis_angle(axis.normalized(), PI)
	else:
		q = Quat.IDENTITY
		var s := sqrt((1.0+d) * 2.0)
		var invs := 1.0 / s
		var c := from.cross(to)

		q.x = c.x * invs
		q.y = c.y * invs
		q.z = c.z * invs
		q.w = s * 0.5
	return q.normalized()
