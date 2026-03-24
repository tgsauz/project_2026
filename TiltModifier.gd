extends SkeletonModification3D

# ============================================================
#  CONFIG
# ============================================================

@export var bone_name: String = "Spine"  # Change to your rig
@export var tilt_multiplier: float = 1.0

# ============================================================
#  INTERNAL
# ============================================================

var bone_idx: int = -1
var tilt: Vector2 = Vector2.ZERO  # x = roll, y = pitch

# ============================================================
#  SETUP
# ============================================================

func _setup_modification(_stack):
	var skeleton = get_skeleton()
	bone_idx = skeleton.find_bone(bone_name)
	assert(bone_idx != -1, "Bone not found: " + bone_name)

# ============================================================
#  API (called externally)
# ============================================================

func set_tilt(value: Vector2):
	tilt = value

# ============================================================
#  EXECUTION
# ============================================================

func _execute(delta):

	if bone_idx == -1:
		return

	var skeleton = get_skeleton()

	# Get current pose
	var pose: Transform3D = skeleton.get_bone_global_pose(bone_idx)

	# Convert tilt into rotation
	var pitch = tilt.y * tilt_multiplier
	var roll = tilt.x * tilt_multiplier

	var rotation = Basis()
	rotation = rotation.rotated(Vector3.RIGHT, pitch)
	rotation = rotation.rotated(Vector3.FORWARD, roll)

	# Apply rotation
	pose.basis = rotation * pose.basis

	skeleton.set_bone_global_pose(bone_idx, pose)
