extends Control

var model_path: String = "res://miku_miku_dance_vrm/art/demo_vrms/4490707391186690073.vrm"
var motion_paths: Array = ["res://miku_miku_dance_vrm/art/demo_vmd/pronama_motion/melt.vmd"]
var vmd_player: VMDPlayer
var animator: VRMAnimator
var max_frame: int

@onready var root = owner
@onready var h_slider: HSlider = get_node("Panel/MarginContainer/VBoxContainer/HSlider")

const gltf_document_extension_class = preload("res://addons/vrm/vrm_extension.gd")

func _unhandled_input(event) -> void:
	if event.is_action_pressed("toggle_ui"):
		visible = !visible


func _copy_user(current_path : String) -> String:	
	var new_path : String = "user://" + current_path.get_file().get_basename() + "." + current_path.get_extension()
	DirAccess.copy_absolute(current_path, new_path)
	return new_path
	
	
func _ready() -> void:
	call_deferred("instance_model")
# warning-ignore:return_value_discarded
	h_slider.connect("value_changed",Callable(self,"_on_time_changed_by_user"))


func instance_model() -> void:
	
	
	var gltf : GLTFDocument = GLTFDocument.new()
	var extension : GLTFDocumentExtension = gltf_document_extension_class.new()
	gltf.register_gltf_document_extension(extension, true)
	var state : GLTFState = GLTFState.new()
	var err = gltf.append_from_file(_copy_user(model_path), state, 1)
	if err != OK:
		return
	var model_instance = gltf.generate_scene(state)	
	if animator:
		animator.queue_free()
		animator = null
	if vmd_player:
		vmd_player.queue_free()
		vmd_player = null
	
	animator = VRMAnimator.new()
	
	vmd_player = VMDPlayer.new()
	
	model_instance.rotate_y(deg_to_rad(180))
	animator.add_child(model_instance)
	root.add_child(animator)
	vmd_player.animator_path = animator.get_path()
	root.add_child(vmd_player)
	if motion_paths.size() > 0:
		instance_motion()

func _process(_delta) -> void:
	if vmd_player:
		h_slider.set_block_signals(true)
		h_slider.max_value = vmd_player.max_frame / 30.0
		h_slider.value = (Time.get_ticks_msec() - vmd_player.start_time) / 1000.0
		h_slider.set_block_signals(false)
	
func _on_time_changed_by_user(value: float) -> void:
	if vmd_player:
		vmd_player.start_time = int(Time.get_ticks_msec() - value * 1000.0)
	
func instance_motion() -> void:
	if motion_paths.size() > 0:
		assert(vmd_player)
		vmd_player.load_motions(motion_paths)
		max_frame = vmd_player.max_frame

func _on_VRMOpenFileDialog_file_selected(path: String):
	model_path = path
	instance_model()
	
func _on_VMDOpenFileDialog_files_selected(paths) -> void:
	motion_paths = paths
	instance_model()
