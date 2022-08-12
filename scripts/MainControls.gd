extends Control

var model_path: String = "res://demo_vrms/4490707391186690073.vrm"
var motion_paths: Array = ["res://demo_vmd/Pronama_motion/melt.vmd"]
var vmd_player: VMDPlayer
var animator: VRMAnimator
var max_frame: int

onready var root = get_node("..")
onready var h_slider: HSlider = get_node("Panel/MarginContainer/VBoxContainer/HSlider")

const VRMImport = preload("res://addons/vrm/import_vrm.gd")

func _unhandled_input(event) -> void:
	if event.is_action_pressed("toggle_ui"):
		visible = !visible


func _copy_user(current_path : String) -> String:	
	var dir = Directory.new()
	var new_path : String = "user://" + current_path.get_file().get_basename() + "." + current_path.get_extension()
	dir.copy(current_path, new_path)
	return new_path
	
	
func _ready() -> void:
	call_deferred("instance_model")
# warning-ignore:return_value_discarded
	h_slider.connect("value_changed", self, "_on_time_changed_by_user")
	call_deferred("_on_VMDOpenFileDialog_files_selected", motion_paths)


func instance_model() -> void:
	var vrm_loader = load("res://addons/vrm/vrm_loader.gd").new()	
	var model_instance : Spatial = vrm_loader.import_scene(_copy_user(model_path), 1, 1000)
	
	if animator:
		animator.queue_free()
		animator = null
	if vmd_player:
		vmd_player.queue_free()
		vmd_player = null
	
	animator = VRMAnimator.new()
	
	vmd_player = VMDPlayer.new()
	
	model_instance.rotate_y(deg2rad(180))
	animator.add_child(model_instance)
	root.add_child(animator)
	vmd_player.animator_path = animator.get_path()
	root.add_child(vmd_player)

func _process(_delta) -> void:
	h_slider.set_block_signals(true)
	h_slider.max_value = vmd_player.max_frame / 30.0
	h_slider.value = (OS.get_ticks_msec() - vmd_player.start_time) / 1000.0
	h_slider.set_block_signals(false)
	
func _on_time_changed_by_user(value: float) -> void:
	vmd_player.start_time = int(OS.get_ticks_msec() - value * 1000.0)
	
func instance_motion() -> void:
	if motion_paths.size() > 0:
		assert(vmd_player, "VMD player must exist")
		vmd_player.load_motions(motion_paths)
		max_frame = vmd_player.max_frame

func _on_VRMOpenFileDialog_file_selected(path: String):
	model_path = path
	instance_model()
	instance_motion()
	
func _on_VMDOpenFileDialog_files_selected(paths) -> void:
	motion_paths = paths
	instance_model()
	instance_motion()
