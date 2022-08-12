extends Spatial

var import_vrm_path : String= "res://addons/vrm/import_vrm.gd"
export(String, FILE) var motion_path
export(String, FILE) var model_path

func _ready():
	var vmd_player: VMDPlayerBake
	var animator: VRMAnimatorBake
	var VRMImport = load(import_vrm_path)
	var model_instance: Spatial
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
	for path in paths:
		var anims : Dictionary = vmd_player.save_motion(path.get_file().get_basename())
		var new_animation_player : AnimationPlayer= model_instance.get_node("anim")
		for key_i in anims.keys():
			new_animation_player.add_animation(key_i, anims[key_i])
		var convert_gltf2 = PackedSceneGLTF.new()
		var filename : String = "user://%s_%s.glb" % [model_path.get_file().get_basename(), path.get_file().get_basename()]
		convert_gltf2.export_gltf(model_instance, filename, 0, 30.0)


func _process(_delta):
	get_tree().quit(0)
