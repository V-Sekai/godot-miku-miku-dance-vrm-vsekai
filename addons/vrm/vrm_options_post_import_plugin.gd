@tool
extends EditorScenePostImportPlugin

signal foo

func _get_import_options(path: String):
	if path.is_empty() or path.get_extension().to_lower() == "vrm":
		add_import_option_advanced(TYPE_INT, "vrm/head_hiding_method", 0, PROPERTY_HINT_ENUM,
			"ThirdPersonOnly,FirstPersonOnly,FirstWithShadow,Layers,LayersWithShadow,IgnoreHeadHiding")
		add_import_option_advanced(TYPE_INT, "vrm/only_if_head_hiding_uses_layers/first_person_layers", 2, PROPERTY_HINT_LAYERS_3D_RENDER)
		add_import_option_advanced(TYPE_INT, "vrm/only_if_head_hiding_uses_layers/third_person_layers", 4, PROPERTY_HINT_LAYERS_3D_RENDER)

func _pre_process(scene: Node) -> void:
	pass

func _post_process(scene: Node) -> void:
	# Fix hips rest pose Y to ensure get_human_scale() returns non-zero value
	var skeleton = _find_skeleton(scene)
	if skeleton:
		var hips_idx = skeleton.find_bone("Hips")  # Hips bone after retargeting
		if hips_idx != -1:
			var rest = skeleton.get_bone_rest(hips_idx)
			if rest.origin.y == 0.0:
				rest.origin.y = 1.0  # Set to 1.0 for proper scaling
				skeleton.set_bone_rest(hips_idx, rest)
				print("Fixed hips rest pose Y to 1.0 for proper VMD animation scaling")

func _find_skeleton(node: Node) -> Skeleton3D:
	for child in node.get_children():
		if child is Skeleton3D:
			return child
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _find_skeleton_path(node: Node, current_path: String = "") -> String:
	for child in node.get_children():
		var child_path = current_path + "/" + child.name if current_path else child.name
		if child is Skeleton3D:
			return child_path
		var found = _find_skeleton_path(child, child_path)
		if found:
			return found
	return ""
