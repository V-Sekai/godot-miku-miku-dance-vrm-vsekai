extends Node

class_name VRMMorphController

const MMD_TO_VRM_MORPH = {
	"まばたき": "blink",
	"ウィンク": "blink_l",
	"ウィンク右": "blink_r",
	"あ": "a",
	"い": "i",
	"う": "u",
	"え": "e",
	"お": "o"
}

var vrm: VRMTopLevel
var mesh_idx_to_mesh = []

func initialize(vrm_top_level: VRMTopLevel, meshes: Array):
	vrm = vrm_top_level
	mesh_idx_to_mesh = meshes

func set_blend_shape_value(blend_shape_name: String, value: float):
	var target_name = blend_shape_name
	if blend_shape_name in MMD_TO_VRM_MORPH:
		target_name = MMD_TO_VRM_MORPH[blend_shape_name]

	for mesh in mesh_idx_to_mesh:
		if mesh is MeshInstance3D and mesh.mesh:
			var blend_shape_count = mesh.mesh.get_blend_shape_count()
			for i in range(blend_shape_count):
				var bs_name = mesh.mesh.get_blend_shape_name(i)
				if bs_name == target_name:
					mesh.set("blend_shapes/" + bs_name, value)
					break
