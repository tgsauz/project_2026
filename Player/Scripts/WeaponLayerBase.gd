extends WeaponLayer
class_name WeaponLayerBase

# ============================================================
# WEAPON LAYER BASE
# First layer in the stack — produces the base weapon transform.
# Priority 0: runs first, all subsequent layers modify this.
#
# Orientation: extracted from ik_hand_gun bone global pose
# (rotation-only, discard scale for valid downstream slerp).
#
# Position: grip-marker-based. Positions the weapon so the RGRIP
# marker aligns with the natural hand position derived from
# clavicle_r + arm_length * IDLE_DIRECTION. This breaks the
# circular dependency:
#   WeaponRoot → GripTarget → arm IK → ik_hand_gun → WeaponRoot
# and makes the weapon follow the body during spine rotation.
# Falls back to spine-coupled positioning when grip markers
# are not available.
# ============================================================

var _skeleton: Skeleton3D
var _gun_bone_idx: int = -1
var _spine_02_idx: int = -1
var _rest_offset_spine_to_weapon: Vector3 = Vector3.ZERO
var _spine_global_rest_rot: Quaternion = Quaternion.IDENTITY
var _spine_rest_global_pos: Vector3 = Vector3.ZERO

var _clavicle_r_idx: int = -1
var _hand_r_idx: int = -1
var _arm_length: float = 0.0
var _rgrip_local: Transform3D = Transform3D.IDENTITY
var _grip_marker_valid: bool = false

## Anatomical constant: direction from clavicle to hand in natural
## idle pose (Y down, Z forward). Works for standard FPS rifle stance.
const IDLE_DIRECTION: Vector3 = Vector3(0.0, -0.8, 0.3)

func _init(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	_gun_bone_idx = skeleton.find_bone("ik_hand_gun")
	_spine_02_idx = skeleton.find_bone("spine_02")
	_clavicle_r_idx = skeleton.find_bone("clavicle_r")
	_hand_r_idx = skeleton.find_bone("hand_r")

	if _spine_02_idx != -1 and _gun_bone_idx != -1:
		var spine_rest_pos: Vector3 = _get_bone_global_rest_pos(_spine_02_idx)
		var gun_rest_pos: Vector3 = _get_bone_global_rest_pos(_gun_bone_idx)
		_rest_offset_spine_to_weapon = gun_rest_pos - spine_rest_pos
		_spine_global_rest_rot = _compute_accumulated_rest_rot(_spine_02_idx)
		_spine_rest_global_pos = _get_bone_global_rest_pos(_spine_02_idx)

	if _clavicle_r_idx != -1 and _hand_r_idx != -1:
		var clavicle_global_rest: Vector3 = _get_bone_global_rest_pos(_clavicle_r_idx)
		var hand_global_rest: Vector3 = _get_bone_global_rest_pos(_hand_r_idx)
		_arm_length = clavicle_global_rest.distance_to(hand_global_rest)

	priority = 0

func apply(current: Transform3D, _state: AimState, _delta: float) -> Transform3D:
	if _skeleton == null or _gun_bone_idx == -1:
		return current

	# Orientation: from ik_hand_gun bone (rotation-only, scale discarded).
	var bone_global: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
	var skel_rot: Quaternion = _skeleton.global_transform.basis.get_rotation_quaternion()
	var bone_rot: Quaternion = bone_global.basis.get_rotation_quaternion()
	var combined_basis := Basis(skel_rot * bone_rot)

	# Position: grip-marker-based or spine-coupled fallback.
	var world_position: Vector3 = _compute_weapon_position(combined_basis)

	return Transform3D(combined_basis, world_position)

## Sets the cached RGRIP local transform (relative to weapon visual).
## Called by WeaponController when a weapon is equipped.
func set_rgrip_local(rgrip: Transform3D) -> void:
	_rgrip_local = rgrip
	_grip_marker_valid = true

# ============================================================
# WEAPON POSITION
# ============================================================

## Dispatches between grip-marker-based positioning (primary) and
## legacy spine-coupled fallback (when grip markers not available).
func _compute_weapon_position(weapon_basis: Basis) -> Vector3:
	if _grip_marker_valid and _clavicle_r_idx != -1 and _arm_length > 0.0:
		return _compute_grip_marker_position(weapon_basis)
	return _compute_spine_coupled_position()

## Positions weapon so RGRIP marker aligns with the natural hand
## position derived from clavicle_r + arm_length * IDLE_DIRECTION.
## No circular dependency: clavicle_r → weapon pos → GripTarget → hand.
func _compute_grip_marker_position(weapon_basis: Basis) -> Vector3:
	# clavicle_r current global pose (skeleton-local, post-spine-modifiers)
	var clavicle_global: Transform3D = _skeleton.get_bone_global_pose(_clavicle_r_idx)

	# Natural hand position in skeleton-local space
	var hand_natural: Vector3 = clavicle_global.origin + _arm_length * IDLE_DIRECTION

	# Transform to world space
	var hand_natural_world: Vector3 = _skeleton.global_transform * hand_natural

	# Grip marker offset in world space (weapon_basis × local offset)
	var grip_offset_world: Vector3 = weapon_basis * _rgrip_local.origin

	# Weapon root position: hand_natural minus grip offset
	return hand_natural_world - grip_offset_world

## Legacy spine-coupled positioning fallback.
## Uses spine_02 rest position + rotated rest offset.
func _compute_spine_coupled_position() -> Vector3:
	if _skeleton == null or _spine_02_idx == -1:
		var bone_global: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
		return _skeleton.global_transform * bone_global.origin

	# Current spine_02 global pose (skeleton-local, post-modifiers)
	var spine_global: Transform3D = _skeleton.get_bone_global_pose(_spine_02_idx)

	# Rotation delta: current accumulated vs rest accumulated.
	# This captures the full rotation the spine has undergone from rest,
	# including parent bones (pelvis, spine_01).
	var spine_current_rot: Quaternion = spine_global.basis.get_rotation_quaternion()
	var rot_delta: Quaternion = spine_current_rot * _spine_global_rest_rot.inverse()

	# Weapon position = spine REST position + rotated rest offset.
	# Using rest position (not current) avoids cancellation between
	# spine translation (from IK) and rotated offset on all axes.
	var weapon_pos_skel: Vector3 = _spine_rest_global_pos + rot_delta * _rest_offset_spine_to_weapon

	return _skeleton.global_transform * weapon_pos_skel

# ============================================================
# ACCUMULATED REST ROTATION
# ============================================================

## Walks up the bone hierarchy from bone_idx to root, accumulating
## rest rotations. Returns the global rest rotation in skeleton-local space.
func _compute_accumulated_rest_rot(bone_idx: int) -> Quaternion:
	var rot := Quaternion.IDENTITY
	var current := bone_idx
	while current != -1:
		rot = _skeleton.get_bone_rest(current).basis.get_rotation_quaternion() * rot
		current = _skeleton.get_bone_parent(current)
	return rot


# ============================================================
# GLOBAL REST POSITION HELPER
# ============================================================

## Returns the global rest position of a bone in skeleton-local space.
## Walks from bone_idx up to root, accumulating transforms:
##   pos = parent_rest.basis * child_rest.origin + parent_rest.origin
## This converts local rest positions into a consistent global frame.
func _get_bone_global_rest_pos(bone_idx: int) -> Vector3:
	var pos := _skeleton.get_bone_rest(bone_idx).origin
	var current := bone_idx
	while true:
		var parent := _skeleton.get_bone_parent(current)
		if parent == -1:
			break
		var parent_rest := _skeleton.get_bone_rest(parent)
		pos = parent_rest.basis * pos + parent_rest.origin
		current = parent
	return pos
