extends WeaponLayer
class_name WeaponLayerAim

# ============================================================
# WEAPON LAYER AIM
# Blends weapon orientation from the base pose to camera-directed
# orientation using aim_orientation_weight.
# Priority 5: runs after WeaponLayerBase.
#
# Responsibility: Orientation blend authority.
#   - At weight=0 → keeps bone orientation (holster pose)
#   - At weight=1 → forces camera-directed orientation
#   - In between → smooth slerp blend
#
# Data consumed:  AimState.aim_orientation_weight, AimState.aim_direction,
#                 AimState.look_pitch, current.basis (bone orientation)
# Data produced:  Transform3D with blended orientation
#
# Invariants:
#   1. Position is always preserved from previous layer (bone grip)
#   2. Orientation is slerped between bone and camera
#   3. Stateless — no internal fields that change over time
# ============================================================

const ROTATION_EPSILON: float = 0.0001
const FLAT_FORWARD_EPSILON: float = 0.001

func _init() -> void:
	priority = 5

func apply(current: Transform3D, state: AimState, _delta: float) -> Transform3D:
	var weight: float = state.aim_orientation_weight
	if weight < 0.001:
		return current

	var bone_orientation: Basis = current.basis
	var camera_orientation: Basis = _build_camera_orientation(state)

	var final_orientation: Basis = bone_orientation.slerp(camera_orientation, weight)
	return Transform3D(final_orientation, current.origin)

func _build_camera_orientation(state: AimState) -> Basis:
	var flat_forward := Vector3(state.aim_direction.x, 0.0, state.aim_direction.z)
	if flat_forward.length_squared() < FLAT_FORWARD_EPSILON:
		flat_forward = Vector3.FORWARD
	else:
		flat_forward = flat_forward.normalized()

	var weapon_forward := flat_forward
	var weapon_right := weapon_forward.cross(Vector3.UP).normalized()
	if weapon_right.length_squared() < FLAT_FORWARD_EPSILON:
		weapon_right = Vector3.RIGHT
		weapon_forward = Vector3.UP.cross(weapon_right).normalized()
	var weapon_up := weapon_right.cross(weapon_forward).normalized()

	var orientation := Basis(weapon_right, weapon_up, -weapon_forward)

	if absf(state.look_pitch) > ROTATION_EPSILON:
		var pitch_rotation := Basis(weapon_right, state.look_pitch)
		orientation = orientation * pitch_rotation

	return orientation
