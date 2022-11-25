class_name MorphBake

var shapes: Dictionary = {}
var animator: VRMAnimatorBake

class VMDBlendShapeBake:
	var name: String
	var weight: float
	func _init(_name: String,_weight: float):
		name = _name
		weight = _weight

func _init(_animator: VRMAnimatorBake,shape_names: Array):
	for shape_name in shape_names:
		shapes[shape_name] = VMDBlendShapeBake.new(shape_name, 0.0)
	animator = _animator

func apply_targets():
	for shape_n in shapes:
		if shape_n == "blink":
			print(shapes[shape_n].weight)
		animator.set_blend_shape_value(shape_n, shapes[shape_n].weight)
