extends SkeletonModifier3D
class_name WeaponOffsetCache

# ============================================================
#  EXPORTS
# ============================================================

@export var chest_bone_name: String = "spine_02"
@export var gun_bone_name: String = "ik_hand_gun"
@export var arm_bone_name: String = "arm_r"

# ============================================================
#  CACHED OFFSET (public — read by WeaponPositionController)
# ============================================================
# spine_02_anim_global⁻¹ * ik_hand_gun_anim_global
# Computed per frame BEFORE any spine modifiers run.
# WeaponPositionController reads this AFTER SpineLookAtController
# to compute: desired_gun = spine_corrected * cached_offset.

var cached_offset: Transform3D = Transform3D.IDENTITY
var gun_anim_global: Transform3D = Transform3D.IDENTITY
var spine_anim_global: Transform3D = Transform3D.IDENTITY
var arm_anim_global: Transform3D = Transform3D.IDENTITY

# ============================================================
#  INTERNAL STATE
# ============================================================

var _skeleton: Skeleton3D
var _chest_bone_idx: int = -1
var _gun_bone_idx: int = -1
var _arm_bone_idx: int = -1

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready() -> void:
	_skeleton = get_skeleton()
	if _skeleton == null:
		push_error("WeaponOffsetCache must be a child of Skeleton3D.")
		return

	_chest_bone_idx = _skeleton.find_bone(chest_bone_name)
	_gun_bone_idx = _skeleton.find_bone(gun_bone_name)

	if _chest_bone_idx == -1:
		push_warning("WeaponOffsetCache: skeleton missing chest bone '%s'." % chest_bone_name)
	if _gun_bone_idx == -1:
		push_warning("WeaponOffsetCache: skeleton missing gun bone '%s'." % gun_bone_name)

	_arm_bone_idx = _skeleton.find_bone(arm_bone_name)
	if _arm_bone_idx == -1:
		push_warning("WeaponOffsetCache: skeleton missing arm bone '%s'." % arm_bone_name)

func _process_modification_with_delta(_delta: float) -> void:
	if _skeleton == null or _chest_bone_idx == -1 or _gun_bone_idx == -1:
		return

	var spine_global: Transform3D = _skeleton.get_bone_global_pose(_chest_bone_idx)
	var gun_global: Transform3D = _skeleton.get_bone_global_pose(_gun_bone_idx)
	spine_anim_global = spine_global
	gun_anim_global = gun_global
	cached_offset = spine_global.affine_inverse() * gun_global

	if _arm_bone_idx != -1:
		arm_anim_global = _skeleton.get_bone_global_pose(_arm_bone_idx)
