extends Spatial

export(String, FILE) var import_vrm_path = "res://addons/vrm/import_vrm.gd"
export(String, FILE) var motion_path
export(String, FILE) var model_path

func _ready():
	var vmd_player: VMDPlayerBake
	var animator: VRMAnimatorBake
	var VRMImport = load(import_vrm_path)
	var model_instance: Spatial
	if model_path.begins_with("res://"):
		model_instance = load(model_path).instance()
	else:
		var vrm_loader = load("res://addons/vrm/vrm_loader.gd").new()
		model_instance = vrm_loader.import_scene(model_path, 1, 1000)
	model_instance.rotate_y(deg2rad(180))
	animator = VRMAnimatorBake.new()
	vmd_player = VMDPlayerBake.new()
	animator.add_child(model_instance)
	add_child(animator)
	vmd_player.animator_path = animator.get_path()
	add_child(vmd_player)
	var paths : Array
	paths.push_back(motion_path)
	vmd_player.load_motions(paths)
	var motions : Array
	var anims : Dictionary = vmd_player.save_motion(motion_path.get_file().get_basename())	
	var new_animation_player : AnimationPlayer= model_instance.get_node("anim")
	for key_i in anims.keys():
		anims[key_i].loop = true
		new_animation_player.add_animation(key_i, anims[key_i])

	var pending_delete : Array
	var queue : Array
	queue.push_back(model_instance)
	while not queue.empty():
		var front = queue.front()
		var node = front
		if node is MeshInstance:
			var mesh : Mesh = node.get_mesh()
			# Has blend shapes then delete to fix bug in Godot Engine
			if VisualServer.mesh_get_blend_shape_count(mesh.get_rid()):
				pending_delete.push_back(node)
#			node.material_override = SpatialMaterial.new()
		var child_count : int = node.get_child_count()
		for i in child_count:
			queue.push_back(node.get_child(i))
		queue.pop_front()
#	_hack_fix_godot_3(pending_delete)

	var gltf : PackedSceneGLTF = PackedSceneGLTF.new()
	gltf.pack(model_instance)
	ResourceSaver.save("res://.import/save_motion.scn", gltf)
#	gltf.export_gltf(model_instance, "res://.import/" + model_path.get_file() + "_" + motion_path.get_file().get_basename() + ".glb")


func _process(_delta):
	get_tree().quit(0)


func _hack_fix_godot_3(pending_delete : Array) -> void:
	while not pending_delete.empty():
		var front = pending_delete.front()
		var node = front
		node.free()
		pending_delete.pop_front()
