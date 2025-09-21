extends Control

var model_path: String = "res://miku_miku_dance_vrm/art/demo_vrms/4490707391186690073.vrm"
var motion_paths: Array = ["res://miku_miku_dance_vrm/art/demo_vmd/pronama_motion/melt.vmd"]
var vmd_player: Node3D
var animator: Node3D
var max_frame: int

@onready var root = owner
@onready var h_slider: HSlider = get_node("Panel/MarginContainer/VBoxContainer/HSlider")

const gltf_document_extension_class = preload("res://addons/vrm/vrm_extension.gd")
const vrm_utils = preload("res://addons/vrm/vrm_utils.gd")

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
	print("Loading VRM model: ", model_path)

	var gltf : GLTFDocument = GLTFDocument.new()
	var extension : GLTFDocumentExtension = gltf_document_extension_class.new()
	gltf.register_gltf_document_extension(extension, true)
	var state : GLTFState = GLTFState.new()
	var err = gltf.append_from_file(_copy_user(model_path), state, 1)
	if err != OK:
		print("Failed to load VRM model, error: ", err)
		return
	print("VRM model loaded successfully")
	var model_instance = gltf.generate_scene(state)
	print("VRM model instantiated")

	if animator:
		animator.queue_free()
		animator = null
	if vmd_player:
		vmd_player.queue_free()
		vmd_player = null

	var animator_script = load("res://addons/vmd_motion/runtime/VRMAnimator.gd")
	animator = Node3D.new()
	animator.set_script(animator_script)
	animator.name = "VRMAnimator"

	var player_script = load("res://addons/vmd_motion/runtime/VMDPlayer.gd")
	vmd_player = Node3D.new()
	vmd_player.set_script(player_script)
	vmd_player.name = "VMDPlayer"

	# Debug: Print scene structure
	print("Model instance children:")
	for child in model_instance.get_children():
		print("  - ", child.name, " (", child.get_class(), ")")

	# Always use the entire model instance (avoid finding VRMTopLevel)
	print("Using entire model instance")
	model_instance.rotate_y(deg_to_rad(180))
	animator.add_child(model_instance)

	# Add animator to root AFTER its children are set up (use call_deferred to ensure timing)
	root.call_deferred("add_child", animator)
	vmd_player.animator_path = NodePath("../VRMAnimator")  # Use relative path
	root.call_deferred("add_child", vmd_player)

	# Defer motion loading to ensure everything is set up
	if motion_paths.size() > 0:
		call_deferred("instance_motion")

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
	print("Loading VMD motion: ", motion_paths)
	if motion_paths.size() > 0:
		assert(vmd_player)
		vmd_player.load_motions(motion_paths)
		max_frame = vmd_player.max_frame
		print("VMD motion loaded, duration: ", max_frame / 30.0, " seconds")
	else:
		print("No motion files provided")

func _on_VRMOpenFileDialog_file_selected(path: String):
	model_path = path
	instance_model()
	
func _on_VMDOpenFileDialog_files_selected(paths) -> void:
	motion_paths = paths
	instance_model()

func _find_skeleton(node: Node) -> Skeleton3D:
	for child in node.get_children():
		if child is Skeleton3D:
			return child
		var found = _find_skeleton(child)
		if found:
			return found
	return null

func _find_vrm_top_level(node: Node) -> Node:
	for child in node.get_children():
		if child is VRMTopLevel:
			return child
		var found = _find_vrm_top_level(child)
		if found:
			return found
	return null
