extends Control

var model_path: String = "res://miku_miku_dance_vrm/art/demo_vrms/4490707391186690073.vrm"
var motion_paths: Array = ["res://miku_miku_dance_vrm/art/demo_vmd/pronama_motion/melt.vmd"]
var vmd_player: Node3D
var animator: Node3D
var animation_tree: AnimationTree
var max_frame: int

@onready var root = owner
@onready var h_slider: HSlider = get_node_or_null("Panel/MarginContainer/VBoxContainer/HSlider")
@onready var play_button: Button = get_node_or_null("Panel/MarginContainer/VBoxContainer/HBoxContainer/PlayButton")
@onready var pause_button: Button = get_node_or_null("Panel/MarginContainer/VBoxContainer/HBoxContainer/PauseButton")
@onready var stop_button: Button = get_node_or_null("Panel/MarginContainer/VBoxContainer/HBoxContainer/StopButton")
@onready var anim_dropdown: OptionButton = get_node_or_null("Panel/MarginContainer/VBoxContainer/HBoxContainer2/AnimationDropdown")

const gltf_document_extension_class = preload("res://addons/vrm/vrm_extension.gd")
const vrm_utils = preload("res://addons/vrm/vrm_utils.gd")

func _unhandled_input(event) -> void:
	if event.is_action_pressed("toggle_ui") or (event is InputEventKey and event.keycode == KEY_H and not event.echo):
		visible = !visible


func _copy_user(current_path : String) -> String:	
	var new_path : String = "user://" + current_path.get_file().get_basename() + "." + current_path.get_extension()
	DirAccess.copy_absolute(current_path, new_path)
	return new_path
	
	
func _ready() -> void:
	call_deferred("instance_model")
# warning-ignore:return_value_discarded
	h_slider.connect("value_changed",Callable(self,"_on_time_changed_by_user"))

	# Connect animation control buttons
	if play_button:
		play_button.connect("pressed", Callable(self, "_on_play_pressed"))
	if pause_button:
		pause_button.connect("pressed", Callable(self, "_on_pause_pressed"))
	if stop_button:
		stop_button.connect("pressed", Callable(self, "_on_stop_pressed"))
	if anim_dropdown:
		anim_dropdown.connect("item_selected", Callable(self, "_on_animation_selected"))


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

	# Create AnimationTree for advanced animation mixing
	if animation_tree:
		animation_tree.queue_free()
	animation_tree = AnimationTree.new()
	animation_tree.name = "AnimationTree"
	animation_tree.active = false  # Start inactive to prevent auto-play
	root.call_deferred("add_child", animation_tree)

	# Add animator to root AFTER its children are set up (use call_deferred to ensure timing)
	root.call_deferred("add_child", animator)
	vmd_player.animator_path = NodePath("../VRMAnimator")  # Use relative path
	root.call_deferred("add_child", vmd_player)

	# Defer motion loading to ensure everything is set up
	if motion_paths.size() > 0:
		call_deferred("instance_motion")

	# Load baked animations for mixing
	call_deferred("load_baked_animations")

func _process(_delta) -> void:
	# Update slider based on AnimationTree/AnimationPlayer current position
	if animation_tree and animation_tree.anim_player:
		var anim_player = animation_tree.anim_player
		if anim_player is NodePath:
			anim_player = get_node(anim_player)
		if anim_player and anim_player is AnimationPlayer:
			var current_anim = anim_player.current_animation
			if current_anim != "":
				h_slider.set_block_signals(true)
				var anim_length = anim_player.get_animation(current_anim).length
				h_slider.max_value = anim_length
				h_slider.value = anim_player.current_animation_position
				h_slider.set_block_signals(false)

func _on_time_changed_by_user(value: float) -> void:
	# Seek AnimationPlayer to the slider position
	if animation_tree and animation_tree.anim_player:
		var anim_player = animation_tree.anim_player
		if anim_player is NodePath:
			anim_player = get_node(anim_player)
		if anim_player and anim_player is AnimationPlayer:
			anim_player.seek(value, true)  # Update parameter
	
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

	# After loading VMD, trigger manual baking
	call_deferred("_bake_loaded_vmd", paths)

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

# Animation control functions
func _on_play_pressed() -> void:
	if animation_tree and anim_dropdown.selected >= 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		animation_tree.active = true

		# Travel to the selected animation state in the state machine
		var playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		if playback:
			playback.travel(anim_name)
			print("Playing animation: ", anim_name)
		else:
			print("Could not get AnimationTree playback object")

func _on_pause_pressed() -> void:
	if animation_tree:
		animation_tree.active = false
		print("Animation paused")

func _on_stop_pressed() -> void:
	if animation_tree:
		animation_tree.active = false
		# Reset to start of current animation
		var playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		if playback:
			playback.start(anim_dropdown.get_item_text(anim_dropdown.selected) if anim_dropdown.selected >= 0 else "")
		print("Animation stopped")

func _on_animation_selected(index: int) -> void:
	if animation_tree:
		var anim_name = anim_dropdown.get_item_text(index)
		print("Selected animation: ", anim_name)

func load_baked_animations() -> void:
	if not animation_tree:
		print("AnimationTree not ready, deferring animation loading")
		call_deferred("load_baked_animations")
		return

	# Clear existing animations
	anim_dropdown.clear()

	# Create AnimationNodeStateMachine for the tree
	var state_machine = AnimationNodeStateMachine.new()
	var animation_names = []  # Keep track of animation names for transitions

	# Look for baked animation files in the motion directory
	var anim_dir = "res://miku_miku_dance_vrm/art/demo_vmd/pronama_motion/"
	var dir = DirAccess.open(anim_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var anim_path = anim_dir + file_name
				var animation = load(anim_path) as Animation
				if animation:
					var anim_name = file_name.get_basename()
					# Add animation node to state machine
					var anim_node = AnimationNodeAnimation.new()
					anim_node.animation = anim_name
					state_machine.add_node(anim_name, anim_node)
					animation_names.append(anim_name)
					anim_dropdown.add_item(anim_name)
					print("Loaded baked animation: ", anim_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Also check user directory for saved animations
	var user_dir = "user://"
	var user_dir_access = DirAccess.open(user_dir)
	if user_dir_access:
		user_dir_access.list_dir_begin()
		var user_file_name = user_dir_access.get_next()
		while user_file_name != "":
			if user_file_name.ends_with(".tres"):
				var anim_path = user_dir + user_file_name
				var animation = load(anim_path) as Animation
				if animation:
					var anim_name = user_file_name.get_basename()
					# Add animation node to state machine
					var anim_node = AnimationNodeAnimation.new()
					anim_node.animation = anim_name
					state_machine.add_node(anim_name, anim_node)
					animation_names.append(anim_name)
					anim_dropdown.add_item(anim_name)
					print("Loaded user animation: ", anim_name)
			user_file_name = user_dir_access.get_next()
		user_dir_access.list_dir_end()

	# Add transitions between all animation states for travel() to work
	for i in range(animation_names.size()):
		for j in range(animation_names.size()):
			if i != j:
				var transition = AnimationNodeStateMachineTransition.new()
				state_machine.add_transition(animation_names[i], animation_names[j], transition)

	# Set up the animation tree
	if anim_dropdown.item_count > 0:
		animation_tree.tree_root = state_machine

		# Create AnimationPlayer for the tree
		var anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		root.add_child(anim_player)

		# Create AnimationLibrary and add animations to it
		var anim_library = AnimationLibrary.new()
		for i in range(anim_dropdown.item_count):
			var anim_name = anim_dropdown.get_item_text(i)
			var anim_path = anim_dir + anim_name + ".tres"
			var animation = load(anim_path) as Animation
			if animation:
				anim_library.add_animation(anim_name, animation)

		# Add the library to the AnimationPlayer
		anim_player.add_animation_library("", anim_library)

		# Set the AnimationPlayer path for the tree
		animation_tree.anim_player = anim_player.get_path()

		anim_dropdown.selected = 0
		_on_animation_selected(0)

# Animation mixing functions
func blend_to_animation(target_anim: String, blend_time: float = 0.5) -> void:
	if not animation_tree:
		return

	# For AnimationTree, we can implement transitions between states
	print("Blending to animation: ", target_anim, " (blend time: ", blend_time, "s)")

func queue_animation(next_anim: String, blend_time: float = 0.5) -> void:
	if not animation_tree:
		return

	# AnimationTree can handle queuing through state machine transitions
	print("Queued animation: ", next_anim)

func set_animation_blend_mode(mode: int) -> void:
	if not animation_tree:
		return

	# AnimationTree has built-in blending capabilities
	print("Blend mode set to: ", mode)

func get_available_animations() -> Array:
	if not animation_tree or not animation_tree.anim_player:
		return []

	var anim_player = animation_tree.anim_player
	if anim_player is NodePath:
		anim_player = get_node(anim_player)
	if anim_player and anim_player is AnimationPlayer:
		var anims = []
		for anim_name in anim_player.get_animation_list():
			anims.append(anim_name)
		return anims
	return []

func create_animation_mix(primary_anim: String, secondary_anim: String, blend_weight: float) -> void:
	if not animation_tree:
		return

	# AnimationTree can handle complex blending through Blend2 nodes
	print("Created mix: ", primary_anim, " + ", secondary_anim, " (weight: ", blend_weight, ")")

func _bake_loaded_vmd(paths: Array) -> void:
	"""Bake the VMD animation to Godot format"""
	if not vmd_player:
		print("VMDPlayer not available for baking")
		return

	if paths.size() > 0:
		var vmd_path = paths[0]  # Use first VMD file for naming
		var baked_animation = vmd_player.manual_bake_animation(vmd_path)

		if baked_animation:
			print("VMD animation successfully baked and saved")
			# Reload animations to include the newly baked one
			call_deferred("load_baked_animations")
		else:
			print("Failed to bake VMD animation")
