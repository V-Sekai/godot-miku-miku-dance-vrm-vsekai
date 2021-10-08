extends Control

var model_path: String = "res://demo_vrms/4490707391186690073.vrm"
var motion_paths: Array = ["res://demo_vmd/Pronama_motion/melt.vmd"]
var vmd_player: VMDPlayerBake
var animator: VRMAnimatorBake
var max_frame: int

onready var root = get_node("..")
onready var h_slider: HSlider = get_node("Panel/MarginContainer/VBoxContainer/HSlider")

const VRMImport = preload("res://addons/vrm/import_vrm.gd")

func _unhandled_input(event):
	if event.is_action_pressed("toggle_ui"):
		visible = !visible


func _copy_user(current_path : String):	
	var dir = Directory.new()
	var new_path : String = "user://" + current_path.get_file().get_basename() + "." + current_path.get_extension()
	dir.copy(current_path, new_path)
	return new_path

func instance_model():
	var vrm_loader = load("res://addons/vrm/vrm_loader.gd").new()	
	var model_instance : Spatial = vrm_loader.import_scene(_copy_user(model_path), 1, 1000)
	
	if animator:
		animator.queue_free()
		animator = null
	if vmd_player:
		vmd_player.queue_free()
		vmd_player = null
	
	animator = VRMAnimatorBake.new()
	
	vmd_player = VMDPlayerBake.new()
	
	model_instance.rotate_y(deg2rad(180))
	animator.add_child(model_instance)
	root.add_child(animator)
	vmd_player.animator_path = animator.get_path()
	root.add_child(vmd_player)

func instance_motion():
	if motion_paths.size() > 0:
		assert(vmd_player, "VMD player must exist")
		vmd_player.load_motions(motion_paths)
		max_frame = vmd_player.max_frame

func _on_VRMOpenFileDialog_file_selected(path: String):
	model_path = path
	instance_model()
	
func _on_VMDOpenFileDialog_files_selected(paths):
	motion_paths = paths
	instance_model()
	bake_motions()


func bake_motions():
	var vmd_player: VMDPlayer
	var animator: VRMAnimator
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
	vmd_player.load_motions(motion_paths)
	var count = 0
	for motion in motion_paths:
		var anims : Dictionary = vmd_player.save_motion(motion.get_file().get_basename())	
		var new_animation_player : AnimationPlayer= model_instance.get_node("anim")
		for key_i in anims.keys():
			anims[key_i].loop = true
			new_animation_player.add_animation(key_i, anims[key_i])
		var gltf : PackedSceneGLTF = PackedSceneGLTF.new()
		gltf.pack(model_instance)
#		ResourceSaver.save("user://save_motion.scn", gltf)
		gltf.export_gltf(model_instance, "user://" + model_path.get_file() + "_" + motion.get_file().get_basename() + str(count) + ".glb")
		model_instance.queue_free()
		count += 1
	OS.shell_open("user://")
