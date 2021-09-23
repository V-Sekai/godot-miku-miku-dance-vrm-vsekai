extends Control

var model_path: String = "res://demo_vrms/4490707391186690073.vrm"
var motion_path: String
var vmd_player: VMDPlayer
var animator: VRMAnimator
var max_frame: int

onready var root = get_node("..")
onready var h_slider: HSlider = get_node("Panel/MarginContainer/VBoxContainer/HSlider")

const VRMImport = preload("res://addons/vrm/import_vrm.gd")

func _unhandled_input(event):
	if event.is_action_pressed("toggle_ui"):
		visible = !visible

func _ready():
	call_deferred("instance_model")
	h_slider.connect("value_changed", self, "_on_time_changed_by_user")

func instance_model():
	var model_instance: Spatial
	if model_path.begins_with("res://"):
		model_instance = load(model_path).instance()
	else:
		var vrm_loader = load("res://addons/vrm/vrm_loader.gd").new()
		model_instance = vrm_loader.import_scene(model_path, 1, 1000)
	
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

func _process(delta):
	h_slider.set_block_signals(true)
	h_slider.max_value = vmd_player.max_frame / 30.0
	h_slider.value = (OS.get_ticks_msec() - vmd_player.start_time) / 1000.0
	h_slider.set_block_signals(false)
	
func _on_time_changed_by_user(value: float):
	vmd_player.start_time = int(OS.get_ticks_msec() - value * 1000.0)
	
func instance_motion():
	if motion_path:
		assert(vmd_player, "VMD player must exist")
		vmd_player.load_motion(motion_path)
		max_frame = vmd_player.max_frame

func _on_VRMOpenFileDialog_file_selected(path: String):
	model_path = path
	instance_model()
	instance_motion()
	
func _on_VMDOpenFileDialog_file_selected(path: String):
	motion_path = path
	instance_model()
	instance_motion()
