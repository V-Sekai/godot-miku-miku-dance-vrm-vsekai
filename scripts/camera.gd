extends Spatial

onready var camera: Spatial = get_node("Spatial/Camera")

func _process(delta):
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var movement = Vector3()
		var local_movement = Vector3()
		if Input.is_action_pressed("forward"):
			local_movement.z -= 1.0
		if Input.is_action_pressed("backwards"):
			local_movement.z += 1.0
		if Input.is_action_pressed("up"):
			local_movement.y += 1.0
		if Input.is_action_pressed("down"):
			local_movement.y -= 1.0
		movement = movement.normalized()
		
		var change = Vector3()
		change += -camera.global_transform.basis.z * movement.z
		change += camera.global_transform.basis.y * movement.y
		change += camera.global_transform.basis.x * movement.x
		
		var movement_multiplier = 1.0
		
		if Input.is_key_pressed(KEY_SHIFT):
			movement_multiplier = 3.0
		global_transform.origin += change * movement_multiplier * delta
		camera.transform.origin += local_movement * delta * movement_multiplier
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * deg2rad(10.0) * get_process_delta_time())
			$Spatial.rotate_x(-event.relative.y * deg2rad(10.0) * get_process_delta_time())
