class_name VMDSkeleton


class VMDSkelBone:
	var name: int
	var node: Node3D
	var local_position_0: Vector3
	
	var target = null
	var target_position: Vector3
	var target_rotation: Quaternion
	
	var skeleton: Skeleton3D
	
	var ik_enabled: bool
	var target_bone_skel_i: int
	
	# source: transform
	# _target: transform
	func _init(_name: int, parent_node: Node3D, source, _target, skel: Skeleton3D, _target_bone_skel_i: int):
		name = _name
		skeleton = skel
		target_bone_skel_i = _target_bone_skel_i
		
		node = Node3D.new()
		node.name = StandardBones.get_bone_name(name)
		parent_node.add_child(node)
		
		if source is Transform3D:
			node.global_transform.origin = source.origin
		local_position_0 = node.transform.origin
		
		if _target is String:
			var bone_idx = skeleton.find_bone(_target)
			if bone_idx != -1:
				target = skeleton.get_bone_global_rest(bone_idx)
				target_position = node.global_transform.affine_inverse() * target.origin
				target_rotation = node.global_transform.basis.get_rotation_quaternion().inverse() * target.basis.get_rotation_quaternion()
		elif _target is Transform3D:
			target = _target
			target_position = node.global_transform.affine_inverse() * target.origin
			target_rotation = node.global_transform.basis.get_rotation_quaternion().inverse() * target.basis.get_rotation_quaternion()
	func apply_target():
		if target != null:
			target.origin = node.global_transform * target_position
			target.basis = Basis(node.global_transform.basis.get_rotation_quaternion() * target_rotation)
			update_pose()
	func update_pose():
		if skeleton == null:
			return
		if target_bone_skel_i == -1:
			return

		# Compute local transform from global target
		var local_transform = target
		var parent_bone = skeleton.get_bone_parent(target_bone_skel_i)
		if parent_bone != -1:
			var parent_global = skeleton.get_bone_global_pose(parent_bone)
			local_transform = parent_global.affine_inverse() * target

		# Debug: Log computed local transform for first few bones
		var bone_name = skeleton.get_bone_name(target_bone_skel_i)
		if target_bone_skel_i < 5:
			print("DEBUG Local Transform - Bone ", target_bone_skel_i, " (", bone_name, ") Local Pos: ", local_transform.origin, " Local Rot: ", local_transform.basis.get_rotation_quaternion())

		# Set local pose
		skeleton.set_bone_pose_position(target_bone_skel_i, local_transform.origin)
		skeleton.set_bone_pose_rotation(target_bone_skel_i, local_transform.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(target_bone_skel_i, local_transform.basis.get_scale())

		# Debug: Log final global position
		if target_bone_skel_i < 5:
			var final_global = skeleton.get_bone_global_pose(target_bone_skel_i)
			print("DEBUG Final Global - Bone ", target_bone_skel_i, " (", bone_name, ") Global Pos: ", final_global.origin, " Global Rot: ", final_global.basis.get_rotation_quaternion())
		
var root: Node3D
var bones: Dictionary
var source_overrides: Array = []
	
func _init(animator: VRMAnimator, root_override = null, source_overrides := {}):
	root = Node3D.new()
	var skel := animator.skeleton
	if not root_override:
		skel.add_child(root)
	else:
		root_override.add_child(root)
	root.global_transform.basis = Basis.IDENTITY
	for i in range(StandardBones.bones.size()):
		var template = StandardBones.bones[i] as StandardBones.StandardBone
		var target_bone_name: String
		if template.target != null:
			target_bone_name = template.target
		bones[template.parent] = VMDSkelBone.new(template.name, root_override, template.source,
		target_bone_name, animator.skeleton, animator.skeleton.find_bone(target_bone_name))
		var parent_node: Node3D

		if bones[template.parent].node:
			parent_node = bones[template.parent].node
		else:
			parent_node = root

		var source_bone_skel_i: int = -1
		var target_bone_skel_i: int = -1

		var source_transform = null

		if template.source:
			source_bone_skel_i = animator.find_humanoid_bone(template.source)
			if source_bone_skel_i == -1:
				print_debug("Cannot pose bone %s" % template.source)
				continue
			source_transform = skel.get_bone_global_rest(source_bone_skel_i)
		if template.target:
			target_bone_skel_i = animator.find_humanoid_bone(template.target)


func apply_targets():
	for i in range(bones.size()):
		var bone = bones[bones.keys()[i]] as VMDSkelBone
		bone.apply_target()
		
func apply_constraints(apply_ik = true, apply_ikq = false):
	for i in range(StandardBones.constraints.size()):
		var constraint = StandardBones.constraints[i] as StandardBones.Constraint
		
		if constraint is StandardBones.RotAdd:
			var target = (bones[bones.keys()[constraint.target]] as VMDSkelBone).node
			var source = (bones[bones.keys()[constraint.source]] as VMDSkelBone).node
			
			if constraint.minus:
				target.global_transform.basis = source.get_parent().global_transform.basis * source.global_transform.basis.inverse() * target.global_transform.basis
			else:
				target.transform.basis = source.transform.basis * target.transform.basis
		elif constraint is StandardBones.LimbIK:
			var upper_leg = bones[constraint.target_0].node as Node3D
			var lower_leg = bones[constraint.target_1].node as Node3D
			var foot = bones[constraint.target_2].node as Node3D
			var foot_ik = bones[constraint.source] as VMDSkelBone
			
			if not foot_ik.ik_enabled:
				continue
			var local_target := upper_leg.global_transform.affine_inverse() * foot_ik.node.global_transform.origin as Vector3
			var bend := -calc_bend(lower_leg.transform.origin, foot.transform.origin, local_target.length())
			lower_leg.transform.basis = Basis(Quaternion(sin(bend/2.0), 0, 0, cos(bend/2.0)))
			var upper_leg_local_rot := upper_leg.transform.basis.get_rotation_quaternion() as Quaternion
			var from = upper_leg.global_transform.affine_inverse() * foot.global_transform.origin
			var to = local_target
			upper_leg.transform.basis = Basis(upper_leg.transform.basis.get_rotation_quaternion() * quat_from_to_rotation(from, to))
		elif constraint is StandardBones.LookAt:
			var foot = bones[bones.keys()[constraint.target_0]].node as Node3D
			var toe = bones[bones.keys()[constraint.target_1]].node as Node3D
			var foot_ik = null if not constraint.source_0 else bones[bones.keys()[constraint.source_0]]
			var toe_ik = null if not constraint.source_1 else bones[bones.keys()[constraint.source_1]]
			
			if foot_ik != null and !foot_ik.ik_enabled:
				continue
			if foot_ik != null and apply_ikq:
				foot.global_transform.basis = foot_ik.node.global_transform.basis
			if toe_ik.ik_enabled:
				var basis : Basis = quat_from_to_rotation(toe.transform.origin, foot.global_transform.affine_inverse() * toe_ik.node.global_transform.origin)
				foot.global_transform.basis *= basis


static func calc_bend(v0: Vector3, v1: Vector3, dist: float) -> float:
		var u0 = Vector2(v0.y, v0.z);
		var u1 = Vector2(v1.y, v1.z);
		var dot = (dist*dist - v0.length_squared() - v1.length_squared())/2 - v0.x*v1.x;
		u1 = Vector2(u0.x*u1.x + u0.y*u1.y, u0.x*u1.y - u1.x*u0.y);
		return max(0.0, acos(clamp(dot/u1.length(), -1, 1)) - atan2(u1.y, u1.x));
			
# Ported from Ogre3D
func quat_from_to_rotation(from: Vector3, to: Vector3) -> Quaternion:
	from = from.normalized()
	to = to.normalized()
	var q = Quaternion()
	var d = from.dot(to)
	if d >= 1.0:
		return Quaternion.IDENTITY
	elif d < (1.0e-6 - 1.0):
		var axis = Vector3.RIGHT.cross(from)
		if axis.length_squared() < (1e-06 * 1e-06):
			axis = Vector3.UP.cross(from)
		q.set_axis_angle(axis.normalized(), PI)
	else:
		q = Quaternion.IDENTITY
		var s := sqrt((1.0+d) * 2.0)
		var invs := 1.0 / s
		var c := from.cross(to)

		q.x = c.x * invs
		q.y = c.y * invs
		q.z = c.z * invs
		q.w = s * 0.5
	return q.normalized()
