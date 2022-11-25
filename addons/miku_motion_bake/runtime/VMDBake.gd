extends Node3D

@export_file var motion_path
@export_file var model_path

const gltf_document_extension_class = preload("res://addons/vrm/vrm_extension.gd")

func _ready():
	var vmd_player: VMDPlayerBake
	var animator: VRMAnimatorBake
	var model_instance: Node3D
	
	
	var gltf : GLTFDocument = GLTFDocument.new()
	var extension : GLTFDocumentExtension = gltf_document_extension_class.new()
	gltf.register_gltf_document_extension(extension)
	var state : GLTFState = GLTFState.new()
	var bake_fps = 30
	var err = gltf.append_from_file(model_path, state, 1, bake_fps)
	if err != OK:
		return null
	model_instance = gltf.generate_scene(state, bake_fps)
	model_instance.rotate_y(deg_to_rad(180))
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
			new_animation_player.add_animation_library(key_i, anims[key_i])
		var gltf_document : GLTFDocument = GLTFDocument.new()
		var gltf_state : GLTFState = GLTFState.new()
		var filename : String = "user://%s_%s.glb" % [model_path.get_file().get_basename(), path.get_file().get_basename()]
		gltf_document.append_from_scene(model_instance, gltf_state, 0, 30)
		gltf_document.write_to_filesystem(gltf_state, filename)

func _process(_delta):
	get_tree().quit(0)
