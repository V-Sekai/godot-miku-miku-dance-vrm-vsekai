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
	# Check if VRM metadata with blend shapes is available (VRM 0.0 style)
	if not vrm or not vrm.vrm_meta or not vrm.vrm_meta.get("blend_shape_groups"):
		return  # VRM 1.0 or no blend shape metadata available

	var meta = vrm.vrm_meta
	var new_bs_name = ""
	if blend_shape_name in MMD_TO_VRM_MORPH:
		blend_shape_name = MMD_TO_VRM_MORPH[blend_shape_name]

	if not meta.blend_shape_groups.has(blend_shape_name):
		return  # Blend shape not found in VRM metadata

	var group = meta.blend_shape_groups[blend_shape_name]
	if not group or not group.binds:
		return  # Invalid blend shape group

	for bind in group.binds:
		if bind.mesh < mesh_idx_to_mesh.size():
			var weight = 0.99999 * float(bind.weight) / 100.0
			var mesh := mesh_idx_to_mesh[bind.mesh] as MeshInstance3D
			if mesh:
				mesh.set("blend_shapes/morph_%d" % [bind.index], value * weight)
