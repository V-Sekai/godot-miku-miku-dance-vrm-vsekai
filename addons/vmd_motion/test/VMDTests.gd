extends Node

## Unit tests for VMD animation system components
## Run these tests to verify each component works independently

const VMDReaderClass = preload("res://addons/vmd_motion/common/VMDReader.gd")
const PoseApplierClass = preload("res://addons/vmd_motion/common/PoseApplier.gd")

func _ready():
	print("Running VMD Unit Tests...")
	run_all_tests()

func run_all_tests():
	test_vmd_reader()
	test_pose_applier()
	test_integration()
	print("All tests completed!")

func test_vmd_reader():
	print("\n--- Testing VMDReader ---")

	# Test creating test data
	var test_data = VMDReaderClass.create_test_data()
	assert(test_data != null, "Should create test data")
	assert(test_data.bone_keyframes.size() > 0, "Should have bone keyframes")
	assert(test_data.bone_keyframes[0].name == "頭", "Should have head bone keyframe")

	# Test finding keyframes for specific bone
	var head_keyframes = test_data.get_bone_keyframes_for_bone("頭")
	assert(head_keyframes.size() == 1, "Should find head keyframes")

	print("✓ VMDReader tests passed")

func test_pose_applier():
	print("\n--- Testing PoseApplier ---")

	# Create test skeleton
	var skeleton = PoseApplierClass.create_test_skeleton()
	assert(skeleton.get_bone_count() == 2, "Should have 2 bones")

	# Test applying bone pose
	var test_pos = Vector3(1, 2, 3)
	var test_rot = Quaternion(0, 1, 0, 0)  # 180 degree rotation around Y
	PoseApplierClass.apply_bone_pose(skeleton, 1, test_pos, test_rot)

	# Verify pose was applied
	var applied_pose = PoseApplierClass.get_bone_pose(skeleton, 1)
	assert(applied_pose.position == test_pos, "Position should be applied")
	assert(applied_pose.rotation == test_rot, "Rotation should be applied")

	# Test validation helper
	var is_valid = PoseApplierClass.validate_bone_pose(skeleton, 1, test_pos, test_rot)
	assert(is_valid, "Pose validation should pass")

	print("✓ PoseApplier tests passed")

func test_integration():
	print("\n--- Testing Integration ---")

	# Create test data and skeleton
	var test_data = VMDReaderClass.create_test_data()
	var skeleton = PoseApplierClass.create_test_skeleton()

	# Find head bone in skeleton
	var head_bone_idx = skeleton.find_bone("Head")
	assert(head_bone_idx != -1, "Should find head bone")

	# Apply VMD data to skeleton
	var head_keyframes = test_data.get_bone_keyframes_for_bone("頭")
	if head_keyframes.size() > 0:
		var keyframe = head_keyframes[0]
		PoseApplierClass.apply_bone_pose(skeleton, head_bone_idx, keyframe.position, keyframe.rotation)

		# Verify it was applied
		var pose = PoseApplierClass.get_bone_pose(skeleton, head_bone_idx)
		assert(pose.position == keyframe.position, "VMD position should be applied")
		assert(pose.rotation == keyframe.rotation, "VMD rotation should be applied")

	print("✓ Integration tests passed")

# Helper function to run tests from editor
static func run_tests():
	var test_instance = VMDTests.new()
	test_instance.run_all_tests()
